/// Lab fixture for [PsdkBridge.readMsr] only — same shape as the Kotlin bridge.
///
/// Used while SDI whitelist is missing. Init / print stay on the native SDK.
/// CVV is not part of MSR/SDI responses; included under [saleFields] for API wiring.
class PsdkMsrMock {
  PsdkMsrMock._();

  static const pan = '6063001014007403';
  static const panDisplay = '6063 0010 1400 7403';
  static const name = 'LILLO ESPINOZA SILVIA DEL';
  static const expiryYyMm = '3012'; // 12/30
  static const expiryUi = '12/30';
  static const cvv = '878';
  static const memberId = '18846764';
  static const serviceCode = '101';

  /// Track2 without sentinels (as SDI typically returns in ASCII).
  static final track2 = '$pan=$expiryYyMm$serviceCode';

  /// Track1 without start/end sentinels / LRC.
  static final track1 = 'B$pan^$name^$expiryYyMm$serviceCode';

  /// Fields ready to map into `POST /v1/transactions`.
  static Map<String, String> get saleFields => {
        'card_number': pan,
        'cvv': cvv,
        'expiration_date': expiryUi,
        'card_holder': name,
        'member_id': memberId,
      };

  /// Payload identical in shape to native `readMsr` success with clear tags.
  static Map<String, dynamic> readMsrSuccess({int timeoutSec = 30}) {
    final panHex = pan; // numeric PAN as hex-ish digits string (BCD-style POC)
    return {
      'ok': true,
      'swipeSeen': true,
      'hasClearData': true,
      'timedOut': false,
      'timeoutSec': timeoutSec,
      'mocked': true,
      'msr': {
        'result': 'OK',
        'panLength': pan.length,
        'panAscii': pan,
        'panHex': panHex,
        'name': name,
        'serviceCode': serviceCode,
        'track1': track1,
        'track2': track2,
        'trackStatusHex': '000002',
        'cardTokenHex': '',
        'responseToString': 'SdiMsrReadResponse(mock)',
      },
      'tags': {
        'fetchResult': 'OK',
        'cleartextDate': true,
        'rawResponseHex': '',
        'rawLength': 0,
        'panHex': panHex,
        'pan': pan,
        'track1Hex': '',
        'track1': track1,
        'track2Hex': '',
        'track2': track2,
        'expiryHex': expiryYyMm,
        'expiry': expiryYyMm,
      },
      'vcl': {
        'statusResult': 'OK',
        'statusHex': '',
        'keyStatusResult': 'OK',
        'keyStatusValue': 0,
      },
      'sale': saleFields,
      'hint':
          'Mock lab swipe (whitelist path). Use tags.pan / tags.track2 / sale.* '
          'to wire API without hardware.',
    };
  }

}

