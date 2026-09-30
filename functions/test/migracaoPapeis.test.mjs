import { describe, expect, it } from 'vitest';
import { planejarMigracao } from '../../scripts/migrarPapeisAdministrativos.mjs';

const papeisSistema = ['ADMINISTRADOR', 'COORDENADOR'];
const doc = (id, dados) => ({ id, data: () => dados });

describe('planejamento da migração de papéis', () => {
  it('normaliza o papel singular sem ressuscitar administradores revogados', () => {
    const { planos, jaNormalizados } = planejarMigracao(
      [
        doc('ativo', { ativa: true, papel: 'ADMINISTRADOR' }),
        doc('revogado', { ativa: false, papel: 'ADMINISTRADOR' }),
        doc('normalizado', { ativa: true, papeis: ['COORDENADOR'] }),
        doc('invalido', { ativa: true, papel: 'PASTOR_LOCAL' }),
      ],
      papeisSistema,
    );

    expect(jaNormalizados).toBe(1);
    const porId = new Map(planos.map((plano) => [plano.id, plano]));
    expect(porId.get('ativo')).toEqual({
      id: 'ativo',
      papeis: ['ADMINISTRADOR'],
      ativa: true,
    });
    expect(porId.get('revogado')).toEqual({
      id: 'revogado',
      papeis: ['ADMINISTRADOR'],
      ativa: false,
    });
    expect(porId.get('invalido')).toEqual({
      id: 'invalido',
      papeis: [],
      ativa: false,
    });
    expect(porId.has('normalizado')).toBe(false);
  });

  it('mescla o campo legado quando `papeis` e `papel` coexistem', () => {
    const { planos, jaNormalizados } = planejarMigracao(
      [
        doc('coexistente', {
          ativa: true,
          papeis: ['COORDENADOR'],
          papel: 'ADMINISTRADOR',
        }),
        doc('plural-vazio-legado', {
          ativa: true,
          papeis: [],
          papel: 'ADMINISTRADOR',
        }),
      ],
      papeisSistema,
    );

    expect(jaNormalizados).toBe(0);
    const porId = new Map(planos.map((plano) => [plano.id, plano]));
    expect(porId.get('coexistente').papeis).toEqual([
      'COORDENADOR',
      'ADMINISTRADOR',
    ]);
    expect(porId.get('plural-vazio-legado').papeis).toEqual(['ADMINISTRADOR']);
    expect(porId.get('plural-vazio-legado').ativa).toBe(true);
  });
});
