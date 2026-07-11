import 'package:flutter_test/flutter_test.dart';
import '../lib/logic.dart';

void main() {
  test('Logic Self Check', () {
    // Redaction check
    final redacted = PrivacyService.redact('Hello, contact me at user@example.com or 01712345678. OTP is 1234.');
    expect(redacted.contains('[EMAIL REDACTED]'), isTrue);
    expect(redacted.contains('[PHONE REDACTED]'), isTrue);
    expect(redacted.contains('[OTP REDACTED]'), isTrue);

    // Template check
    final replies = TemplateEngine.generate(
      intent: MessageIntent.paymentReminder,
      tone: 'Polite',
      language: 'Bangla',
    );
    expect(replies.isNotEmpty, isTrue);
    expect(replies.length <= 3, isTrue);

    print('--- ALL SELF-CHECKS PASSED SUCCESSFULLY! ---');
  });
}
