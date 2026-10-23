// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class PickedUploadFile {
  const PickedUploadFile({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

Future<PickedUploadFile?> pickUploadFile({
  required List<String> allowedExtensions,
  String? accept,
}) async {
  final input = html.FileUploadInputElement()
    ..multiple = false
    ..accept = accept ?? allowedExtensions.map((item) => '.$item').join(',');
  input.style.display = 'none';
  html.document.body?.append(input);

  final completer = Completer<PickedUploadFile?>();
  late final StreamSubscription<html.Event> changeSubscription;

  void complete(PickedUploadFile? file) {
    if (completer.isCompleted) return;
    changeSubscription.cancel();
    input.remove();
    completer.complete(file);
  }

  changeSubscription = input.onChange.listen((_) {
    final file = input.files?.isEmpty == false ? input.files!.first : null;
    if (file == null) {
      complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onError.first.then((_) => complete(null));
    reader.onLoad.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        complete(PickedUploadFile(
          name: file.name,
          bytes: Uint8List.view(result),
        ));
      } else if (result is Uint8List) {
        complete(PickedUploadFile(name: file.name, bytes: result));
      } else {
        complete(null);
      }
    });
    reader.readAsArrayBuffer(file);
  });

  html.window.onFocus.first.then((_) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!completer.isCompleted &&
        (input.files == null || input.files!.isEmpty)) {
      complete(null);
    }
  });

  input.click();
  return completer.future;
}
