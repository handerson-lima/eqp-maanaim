import 'package:flutter/material.dart';

const azulMaanaim = Color(0xFF005BD8);
const marinhoMaanaim = Color(0xFF0C2940);
const fundoMaanaim = Color(0xFFF3F7FB);
const bordaMaanaim = Color(0xFFDCE5EF);

ThemeData temaMaanaim() {
  final esquema = ColorScheme.fromSeed(seedColor: azulMaanaim).copyWith(
    primary: azulMaanaim,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: const Color(0xFF13233D),
    onSurfaceVariant: const Color(0xFF50627A),
    outline: const Color(0xFF74849A),
  );
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: fundoMaanaim,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF13233D),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerColor: bordaMaanaim,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: bordaMaanaim),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF74849A)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: azulMaanaim,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 48),
        elevation: 0,
        shape: forma,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: forma,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
    ),
  );
}

/// Moldura compartilhada: marca lateral em telas amplas e topo compacto no celular.
class PainelAcesso extends StatelessWidget {
  const PainelAcesso({super.key, required this.child});
  final Widget child;

  Widget _marca(bool ampla) => Container(
    padding: EdgeInsets.all(ampla ? 48 : 24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF18486D), marinhoMaanaim],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Maanaim',
          style: TextStyle(
            color: Colors.white,
            fontSize: ampla ? 40 : 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Gestão de Voluntários',
          style: TextStyle(color: Colors.white),
        ),
        if (ampla) ...[
          const SizedBox(height: 80),
          const Text(
            'Servindo juntos no Reino de Deus',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.6),
          ),
          const SizedBox(height: 16),
          const Text(
            '“Cada um exerça o dom que recebeu para servir aos outros”\n1 Pedro 4:10',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFD8E7F5), height: 1.6),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, tamanho) {
      final ampla = tamanho.maxWidth >= 900;
      final formulario = Padding(
        padding: EdgeInsets.all(ampla ? 40 : 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(ampla ? 32 : 24),
                child: child,
              ),
            ),
          ),
        ),
      );
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tamanho.maxHeight),
          child: ampla
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: tamanho.maxHeight,
                        ),
                        child: _marca(true),
                      ),
                    ),
                    Expanded(flex: 5, child: formulario),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_marca(false), formulario],
                ),
        ),
      );
    },
  );
}
