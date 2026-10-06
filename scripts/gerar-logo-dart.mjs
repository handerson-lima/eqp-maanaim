import fs from 'node:fs';

const b64 = fs.readFileSync('flutter_app/assets/images/logo_maranata.png').toString('base64');
const content = `import 'dart:convert';
import 'dart:typed_data';

/// Imagem oficial da logo da Igreja Cristã Maranata codificada em PNG Base64.
/// Utilizada para renderização em tela e injeção síncrona no HTML de impressão/PDF.
const String kLogoMaranataPngBase64 =
    '${b64}';

final Uint8List kLogoMaranataBytes = base64Decode(kLogoMaranataPngBase64);
`;

fs.writeFileSync('flutter_app/lib/features/termo/termo_logo_asset.dart', content, 'utf-8');
console.log('Criado termo_logo_asset.dart com sucesso.');
