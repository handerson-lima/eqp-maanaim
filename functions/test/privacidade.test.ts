import { describe, expect, it } from 'vitest';
import {
  ANOS_RETENCAO,
  CPF_MASCARADO,
  POLITICA_RETENCAO_ID,
  calcularRetencaoAte,
  contemPii,
  chaveContemPii,
  mascararTexto,
  sanitizarErro,
  sanitizarPii,
} from '../src/domain/privacidade.js';

describe('Story 6.4: Sanitizador canônico de PII (AD-12)', () => {
  it('identifica chaves que denotam PII ou segredos', () => {
    expect(chaveContemPii('nomeCompleto')).toBe(true);
    expect(chaveContemPii('cpf')).toBe(true);
    expect(chaveContemPii('cpfVoluntario')).toBe(true);
    expect(chaveContemPii('enderecoResidencial')).toBe(true);
    expect(chaveContemPii('fcmToken')).toBe(true);
    expect(chaveContemPii('tokenSessao')).toBe(true);
    expect(chaveContemPii('assinaturaPrivada')).toBe(true);
    expect(chaveContemPii('acao')).toBe(false);
    expect(chaveContemPii('motivo')).toBe(false);
    expect(chaveContemPii('estado')).toBe(false);
  });

  it('remove recursivamente chaves de PII e segredos preservando o schema permitido', () => {
    const entrada = {
      id: 'cmd-1',
      acao: 'ANONIMIZAR_FICHA',
      estado: 'EXPIRADA',
      motivo: 'SOLICITACAO_TITULAR',
      atorUid: 'uid-coordenador',
      nomeCompleto: 'Maria Souza',
      cpf: '123.456.789-00',
      email: 'maria@exemplo.com',
      telefone: '(84) 99999-0000',
      endereco: 'Rua X, 10',
      fcmToken: 'fcm-abc',
      aninhado: {
        token: 'segredo',
        observacao: 'registro permitido',
      },
      participacoes: [
        { id: 'part-1', estado: 'EXPIRADA', nomeCompleto: 'Maria Souza' },
      ],
    };

    const sanitizado = sanitizarPii(entrada) as Record<string, unknown>;
    expect(sanitizado.id).toBe('cmd-1');
    expect(sanitizado.acao).toBe('ANONIMIZAR_FICHA');
    expect(sanitizado.estado).toBe('EXPIRADA');
    expect(sanitizado.motivo).toBe('SOLICITACAO_TITULAR');
    expect(sanitizado.atorUid).toBe('uid-coordenador');
    expect(sanitizado.nomeCompleto).toBeUndefined();
    expect(sanitizado.cpf).toBeUndefined();
    expect(sanitizado.email).toBeUndefined();
    expect(sanitizado.telefone).toBeUndefined();
    expect(sanitizado.endereco).toBeUndefined();
    expect(sanitizado.fcmToken).toBeUndefined();
    expect((sanitizado.aninhado as Record<string, unknown>).token).toBeUndefined();
    expect((sanitizado.aninhado as Record<string, unknown>).observacao).toBe(
      'registro permitido',
    );
    const partes = sanitizado.participacoes as Array<Record<string, unknown>>;
    expect(partes[0].id).toBe('part-1');
    expect(partes[0].estado).toBe('EXPIRADA');
    expect(partes[0].nomeCompleto).toBeUndefined();
  });

  it('mascara CPF, e-mail e telefone em texto livre', () => {
    const texto =
      'Contato maria.souza@exemplo.com CPF 123.456.789-00 tel (84) 98888-7777.';
    const mascarado = mascararTexto(texto);
    expect(mascarado).not.toContain('maria.souza@exemplo.com');
    expect(mascarado).not.toContain('123.456.789-00');
    expect(mascarado).not.toContain('98888-7777');
    expect(mascarado).toContain(CPF_MASCARADO);
  });

  it('contemPii detecta PII por chave ou por padrão em string', () => {
    expect(contemPii({ nomeCompleto: 'X' })).toBe(true);
    expect(contemPii({ observacao: 'CPF 123.456.789-00' })).toBe(true);
    expect(contemPii({ id: 'ok', estado: 'ATIVA' })).toBe(false);
  });

  it('sanitizarErro nunca devolve PII e trunca a mensagem', () => {
    const erro = new Error(`Falha para maria@exemplo.com CPF 123.456.789-00 ${'x'.repeat(500)}`);
    const sanitizado = sanitizarErro(erro);
    expect(sanitizado.nome).toBe('Error');
    expect(sanitizado.mensagem).not.toContain('maria@exemplo.com');
    expect(sanitizado.mensagem).not.toContain('123.456.789-00');
    expect(sanitizado.mensagem.length).toBeLessThanOrEqual(300);
  });

  it('calcula retenção de 5 anos em UTC', () => {
    const base = '2026-10-07T12:00:00.000Z';
    const resultado = calcularRetencaoAte(base);
    expect(resultado).toBe('2031-10-07T12:00:00.000Z');
    expect(POLITICA_RETENCAO_ID).toBe('AD-12_V1');
    expect(ANOS_RETENCAO).toBe(5);
  });

  it('rejeita data base inválida no cálculo de retenção', () => {
    expect(() => calcularRetencaoAte('data-invalida')).toThrow();
  });
});
