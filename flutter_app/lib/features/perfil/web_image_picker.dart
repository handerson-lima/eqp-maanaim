export 'web_image_picker_stub.dart'
    if (dart.library.html) 'web_image_picker_html.dart'
    if (dart.library.js_interop) 'web_image_picker_html.dart';
