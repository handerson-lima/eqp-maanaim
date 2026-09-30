import { describe, expect, it } from 'vitest';
import {
  calcularHashConteudo,
  calcularPayloadHash,
  validarPublicarTermo,
  TermoInvalidoError,
  TIPO_TERMO_PADRAO,
  TERMO_ID_PADRAO,
  type EntradaPublicarTermo,
} from '../src/domain/termos.js';

describe('domínio de termos', () => {
  const base = {
    commandId: 'c'.repeat(32),
    correlationId: 'corr-1',
    titulo: 'Termo de Adesão ao Serviço Voluntário Maanaim',
    conteudo: 'Este é o conteúdo integral do termo de adesão ao serviço voluntário do Maanaim, com todas as cláusulas e compromissos.',
    expectedVersion: 0,
  };

  it('valida entrada correta com defaults canônicos', () => {
    const entrada = validarPublicarTermo(base);
    expect(entrada.termoId).toBe(TERMO_ID_PADRAO);
    expect(entrada.tipoTermo).toBe(TIPO_TERMO_PADRAO);
    expect(entrada.titulo).toBe(base.titulo);
    expect(entrada.conteudo).toBe(base.conteudo);
    expect(entrada.expectedVersion).toBe(0);
    expect(entrada.payloadHash).toHaveLength(64);
    expect(entrada.hashConteudo).toHaveLength(64);
  });

  it('calcula o mesmo hash SHA-256 para mesmo conteúdo normalizado', () => {
    const hash1 = calcularHashConteudo('Título', 'Conteúdo canônico longo para validação de teste');
    const hash2 = calcularHashConteudo('  Título  ', '  Conteúdo canônico longo para validação de teste  ');
    expect(hash1).toBe(hash2);
    expect(hash1).toMatch(/^[a-f0-9]{64}$/);
  });

  it('calcula hash diferente para conteúdos divergentes', () => {
    const hash1 = calcularHashConteudo('Título', 'Conteúdo canônico longo para validação de teste 1');
    const hash2 = calcularHashConteudo('Título', 'Conteúdo canônico longo para validação de teste 2');
    expect(hash1).not.toBe(hash2);
  });

  it('rejeita título curto ou vazio', () => {
    expect(() => validarPublicarTermo({ ...base, titulo: 'ab' })).toThrow(TermoInvalidoError);
    expect(() => validarPublicarTermo({ ...base, titulo: '' })).toThrow(TermoInvalidoError);
    expect(() => validarPublicarTermo({ ...base, titulo: '   ' })).toThrow(TermoInvalidoError);
  });

  it('rejeita conteúdo menor que 20 caracteres', () => {
    expect(() => validarPublicarTermo({ ...base, conteudo: 'curto' })).toThrow(TermoInvalidoError);
    expect(() => validarPublicarTermo({ ...base, conteudo: '' })).toThrow(TermoInvalidoError);
  });

  it('rejeita commandId inválido ou ausente', () => {
    expect(() => validarPublicarTermo({ ...base, commandId: '' })).toThrow(TermoInvalidoError);
    expect(() => validarPublicarTermo({ ...base, commandId: 'curto' })).toThrow(TermoInvalidoError);
  });

  it('aceita expectedVersion positivo para novas versões', () => {
    const entrada = validarPublicarTermo({ ...base, expectedVersion: 1 });
    expect(entrada.expectedVersion).toBe(1);
  });

  it('calcula payloadHash determinístico', () => {
    const e1 = validarPublicarTermo(base);
    const e2 = validarPublicarTermo(base);
    expect(e1.payloadHash).toBe(e2.payloadHash);
  });
});
