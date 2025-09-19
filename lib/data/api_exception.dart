class AppException implements Exception{
  final _message;
  final _prefix;

  AppException(this._message, this._prefix);
  String toString(){
    return '$_prefix$_message';
  }
}
class FetchDataException extends AppException{
  FetchDataException([String?message]):super(message,"");
}
class NoDataException extends AppException{
  NoDataException([String?message]):super(message,"");
}
class BadRequestException extends AppException{
  BadRequestException([String?message]):super(message,"Invalid Request!! ");
}

class UnAuthorizeException extends AppException{
  UnAuthorizeException([String?message]):super(message,"Unauthorized Request ");
}

class InvalidInputException extends AppException{
  InvalidInputException([String?message]):super(message,"Unauthorized Request ");
}
class StorageException extends AppException {
  StorageException([String? message]) : super(message, "Storage Permission Error: ");
}