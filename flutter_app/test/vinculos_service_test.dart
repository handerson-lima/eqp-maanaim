import 'package:eqp_maanaim/features/admin/vinculos_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _id(String caractere) => List.filled(32, caractere).join();

void main() {
  test('formatarDataEfetiva usa o dia escolhido sem deslocar fuso', () {
    expect(formatarDataEfetiva(DateTime(2026, 3, 9)), '2026-03-09');
    expect(formatarDataEfetiva(DateTime.utc(2026, 1, 5)), '2026-01-05');
  });

  test('montarPayloadVinculo envia YYYY-MM-DD e expectedVersion', () {
    final payload = montarPayloadVinculo(
      commandId: _id('a'),
      tipoEntidade: 'IGREJA',
      entidadeId: 'ig-1',
      acao: 'SUBSTITUIR',
      pessoaId: 'pessoa-1',
      dataEfetiva: DateTime(2026, 7, 4, 23, 59),
      versao: 3,
      justificativa: '  troca  ',
    );
    expect(payload['dataEfetiva'], '2026-07-04');
    expect(payload['expectedVersion'], 3);
    expect(payload['acao'], 'SUBSTITUIR');
    expect(payload['pessoaId'], 'pessoa-1');
    expect(payload['justificativa'], 'troca');
  });

  test('montarPayloadVinculo omite pessoa e justificativa vazias', () {
    final payload = montarPayloadVinculo(
      commandId: _id('b'),
      tipoEntidade: 'EQUIPE',
      entidadeId: 'eq-1',
      acao: 'ENCERRAR',
      dataEfetiva: DateTime(2026, 7, 4),
      versao: 0,
      justificativa: '   ',
    );
    expect(payload.containsKey('pessoaId'), isFalse);
    expect(payload.containsKey('justificativa'), isFalse);
    expect(payload['expectedVersion'], 0);
  });

  test('mapearItemVinculo mapeia responsável e linha do tempo', () {
    final item = mapearItemVinculo({
      'id': 'ig-1',
      'tipoEntidade': 'IGREJA',
      'rotulo': 'Goianinha - 240008',
      'codigo': '240008',
      'ativo': true,
      'versaoVinculo': 2,
      'responsavel': {'pessoaId': 'p1', 'nome': 'João Batista'},
      'historico': [
        {
          'acao': 'SUBSTITUIR',
          'papel': 'PASTOR_LOCAL',
          'estado': 'VIGENTE',
          'atorUid': 'admin1',
          'atorNome': 'Administrador',
          'inicioVigencia': '2026-01-05T14:30:00.000Z',
          'fimVigencia': null,
          'justificativa': 'troca pastoral',
          'encerradoPorUid': null,
        },
      ],
    });
    expect(item.id, 'ig-1');
    expect(item.tipoEntidade, 'IGREJA');
    expect(item.rotulo, 'Goianinha - 240008');
    expect(item.codigo, '240008');
    expect(item.ativo, isTrue);
    expect(item.versaoVinculo, 2);
    expect(item.responsavel?.pessoaId, 'p1');
    expect(item.responsavel?.nome, 'João Batista');
    expect(item.historico, hasLength(1));
  });

  test('mapearItemVinculo tolera ausência de responsável', () {
    final item = mapearItemVinculo({'id': 'eq-1', 'rotulo': 'Apoio'});
    expect(item.responsavel, isNull);
    expect(item.temResponsavel, isFalse);
    expect(item.tipoEntidade, 'IGREJA');
    expect(item.historico, isEmpty);
  });

  test('mapearEventoVinculo normaliza timestamps e campos', () {
    final evento = mapearEventoVinculo({
      'acao': 'ENCERRAR',
      'papel': 'PASTOR_EQUIPE',
      'estado': 'ENCERRADO',
      'atorUid': 'admin2',
      'atorNome': 'Coord',
      'inicioVigencia': '2026-01-05T14:30:00.000Z',
      'fimVigencia': '2026-02-01T00:00:00.000Z',
      'justificativa': 'fim',
      'encerradoPorUid': 'admin2',
    });
    expect(evento.acao, 'ENCERRAR');
    expect(evento.papel, 'PASTOR_EQUIPE');
    expect(evento.estado, 'ENCERRADO');
    expect(evento.vigente, isFalse);
    expect(evento.inicioVigencia, DateTime.utc(2026, 1, 5, 14, 30));
    expect(evento.fimVigencia, DateTime.utc(2026, 2, 1));
    expect(evento.justificativa, 'fim');
    expect(evento.encerradoPorUid, 'admin2');
  });

  test('mapearEventoVinculo tolera campos ausentes', () {
    final evento = mapearEventoVinculo({});
    expect(evento.acao, 'ATRIBUIR');
    expect(evento.estado, 'VIGENTE');
    expect(evento.inicioVigencia, isNull);
    expect(evento.fimVigencia, isNull);
  });

  test('mapearListaVinculos tolera lista nula ou vazia', () {
    expect(mapearListaVinculos(null), isEmpty);
    expect(mapearListaVinculos(const []), isEmpty);
    expect(mapearListaVinculos([
      {'id': 'ig-1', 'rotulo': 'Igreja'},
    ]).single.rotulo, 'Igreja');
  });
}
