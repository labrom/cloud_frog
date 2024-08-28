import 'package:dart_frog/dart_frog.dart';

extension OptionalDependency on RequestContext {
  T? readOptional<T>() {
    try {
      return read<T>();
    } catch (_) {
      return null;
    }
  }
}
