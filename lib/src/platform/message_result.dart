/// VNPT iOS `MESSAGE_RESULT` values used by Flutter on both platforms.
abstract final class MessageResult {
  static const int invalid = -1;
  static const int noFace = 0;
  static const int fit = 1;
  static const int tooFar = 2;
  static const int tooNear = 3;
  static const int timeExceed = 4;
  static const int notStraight = 5;
  static const int awayFromLeft = 6;
  static const int awayFromTop = 7;
  static const int awayFromRight = 8;
  static const int awayFromBottom = 9;
  static const int awayFromCenter = 10;
  static const int manyFaces = 19;
  static const int cardValid = 20;
  static const int noCard = 21;

  static const Set<int> cardHints = {
    noCard,
    22, // cardBright
    27, // cardBlur
    28, // cardNear
    29, // cardFar
    30, // cardTilt
    23,
    24,
    25,
    26,
  };
}
