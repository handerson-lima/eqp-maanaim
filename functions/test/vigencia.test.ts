import { describe, expect, it } from 'vitest';
import {
  adicionarUmAnoUtc,
  calcularVigenciaAnual,
  classificarVigencia,
} from '../src/domain/vigencia.js';

describe('Story 5.1: Domínio de Vigência Anual e Alertas de Renovação', () => {
  describe('Cálculo de Vigência de 1 Ano (AD-7)', () => {
    it('adiciona exatamente 1 ano em UTC para uma data padrão', () => {
      const inicio = new Date('2026-05-15T14:30:00.000Z');
      const resultado = calcularVigenciaAnual(inicio);

      expect(resultado.vigenciaInicio.toISOString()).toBe('2026-05-15T14:30:00.000Z');
      expect(resultado.vigenciaFim.toISOString()).toBe('2027-05-15T14:30:00.000Z');
      expect(resultado.anoVigencia).toBe(2026);
    });

    it('ajusta 29 de fevereiro de ano bissexto para 28 de fevereiro no ano não bissexto seguinte', () => {
      // 2024 é ano bissexto
      const bissexto = new Date('2024-02-29T12:00:00.000Z');
      const resultado = adicionarUmAnoUtc(bissexto);

      expect(resultado.getUTCFullYear()).toBe(2025);
      expect(resultado.getUTCMonth()).toBe(1); // Fevereiro (0-indexed)
      expect(resultado.getUTCDate()).toBe(28);
    });
  });

  describe('Classificação Temporal de Vigência e Alertas (AD-10 / AD-12)', () => {
    const agora = new Date('2026-10-01T12:00:00.000Z');

    it('retorna NAO_APLICAVEL quando vigenciaFim é nulo ou indefinido', () => {
      const classif = classificarVigencia(agora, null);
      expect(classif.situacao).toBe('NAO_APLICAVEL');
      expect(classif.diasRestantes).toBeNull();
      expect(classif.alerta).toBeNull();
      expect(classif.emAlertaRenovacao).toBe(false);
    });

    it('classifica como VIGENTE sem alertas quando faltam mais de 60 dias (ex: 90 dias)', () => {
      const vigenciaFim = new Date('2026-12-30T12:00:00.000Z'); // 90 dias
      const classif = classificarVigencia(agora, vigenciaFim);

      expect(classif.situacao).toBe('VIGENTE');
      expect(classif.diasRestantes).toBe(90);
      expect(classif.alerta).toBeNull();
      expect(classif.emAlertaRenovacao).toBe(false);
      expect(classif.janelaRenovacaoAberta).toBe(false);
    });

    it('classifica como ALERTA_PREVIO_60D quando faltam entre 31 e 60 dias (ex: 45 dias)', () => {
      const vigenciaFim = new Date('2026-11-15T12:00:00.000Z'); // 45 dias
      const classif = classificarVigencia(agora, vigenciaFim);

      expect(classif.situacao).toBe('ALERTA_PREVIO_60D');
      expect(classif.diasRestantes).toBe(45);
      expect(classif.alerta).toBe('Aviso de renovação: vence em 45 dias');
      expect(classif.emAlertaRenovacao).toBe(true);
      expect(classif.janelaRenovacaoAberta).toBe(true);
    });

    it('classifica como RENOVACAO_IMINENTE_30D quando faltam 30 dias ou menos (ex: 15 dias)', () => {
      const vigenciaFim = new Date('2026-10-16T12:00:00.000Z'); // 15 dias
      const classif = classificarVigencia(agora, vigenciaFim);

      expect(classif.situacao).toBe('RENOVACAO_IMINENTE_30D');
      expect(classif.diasRestantes).toBe(15);
      expect(classif.alerta).toBe('Renovação necessária: vence em 15 dias');
      expect(classif.emAlertaRenovacao).toBe(true);
      expect(classif.janelaRenovacaoAberta).toBe(true);
    });

    it('formata texto singular quando resta exatamente 1 dia', () => {
      const vigenciaFim = new Date('2026-10-02T12:00:00.000Z'); // 1 dia
      const classif = classificarVigencia(agora, vigenciaFim);

      expect(classif.situacao).toBe('RENOVACAO_IMINENTE_30D');
      expect(classif.diasRestantes).toBe(1);
      expect(classif.alerta).toBe('Renovação necessária: vence em 1 dia');
    });

    it('classifica como EXPIRADA quando a data limite já passou', () => {
      const vigenciaFim = new Date('2026-09-30T12:00:00.000Z'); // -1 dia
      const classif = classificarVigencia(agora, vigenciaFim);

      expect(classif.situacao).toBe('EXPIRADA');
      expect(classif.diasRestantes).toBeLessThanOrEqual(0);
      expect(classif.alerta).toBe('Vigência anual expirada');
      expect(classif.emAlertaRenovacao).toBe(true);
      expect(classif.janelaRenovacaoAberta).toBe(true);
    });

    it('permite sobrescrever janelas de aviso prévio e renovação iminente por configuração', () => {
      const vigenciaFim = new Date('2026-10-21T12:00:00.000Z'); // 20 dias
      // Configuração customizada: renovação iminente em 10 dias, aviso em 25 dias
      const classif = classificarVigencia(agora, vigenciaFim, {
        diasAvisoPrevio: 25,
        diasRenovacaoIminente: 10,
      });

      expect(classif.situacao).toBe('ALERTA_PREVIO_60D');
      expect(classif.diasRestantes).toBe(20);
    });

    it('assegura minimização de dados: nenhum alerta contém PII, nomes ou emails', () => {
      const vigenciaFim = new Date('2026-10-15T12:00:00.000Z');
      const classif = classificarVigencia(agora, vigenciaFim);

      expect(classif.alerta).not.toMatch(/@/);
      expect(classif.alerta).not.toMatch(/Pastor/i);
      expect(classif.alerta).not.toMatch(/Coordenador/i);
    });
  });
});
