import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Intents definition
enum MessageIntent {
  greeting,
  request,
  invitation,
  apology,
  complaint,
  paymentReminder,
  work,
  customerQuery,
  boundary,
  appreciation,
  general,
}

// State model for the generation flow
class ReplyState {
  final String? imagePath;
  final String rawText;
  final String redactedText;
  final MessageIntent intent;
  final String tone; // Polite, Friendly, Formal, Direct, Funny, Polite No
  final String language; // English, Hindi, Hinglish, Bengali, Banglish, Tamil, Telugu
  final List<String> generatedReplies;

  ReplyState({
    this.imagePath,
    this.rawText = '',
    this.redactedText = '',
    this.intent = MessageIntent.general,
    this.tone = 'Polite',
    this.language = 'English',
    this.generatedReplies = const [],
  });

  ReplyState copyWith({
    String? imagePath,
    String? rawText,
    String? redactedText,
    MessageIntent? intent,
    String? tone,
    String? language,
    List<String>? generatedReplies,
  }) {
    return ReplyState(
      imagePath: imagePath ?? this.imagePath,
      rawText: rawText ?? this.rawText,
      redactedText: redactedText ?? this.redactedText,
      intent: intent ?? this.intent,
      tone: tone ?? this.tone,
      language: language ?? this.language,
      generatedReplies: generatedReplies ?? this.generatedReplies,
    );
  }
}

// Riverpod Provider for Reply Generation State
class ReplyNotifier extends StateNotifier<ReplyState> {
  ReplyNotifier() : super(ReplyState());

  final _textRecognizer = TextRecognizer();

  void reset() {
    state = ReplyState();
  }

  void updateText(String text) {
    final redacted = PrivacyService.redact(text);
    state = state.copyWith(rawText: text, redactedText: redacted);
    detectIntent();
  }

  void updateRedactedText(String redacted) {
    state = state.copyWith(redactedText: redacted);
  }

  void updateTone(String tone) {
    state = state.copyWith(tone: tone);
    generateReplies();
  }

  void updateLanguage(String language) {
    state = state.copyWith(language: language);
    generateReplies();
  }

  void updateIntent(MessageIntent intent) {
    state = state.copyWith(intent: intent);
    generateReplies();
  }

  Future<void> processImage(String path) async {
    state = state.copyWith(imagePath: path, rawText: 'Processing OCR...');
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      updateText(recognizedText.text);
    } catch (e) {
      updateText('OCR failed to extract text. Please enter/edit manually.');
    }
  }

  void detectIntent() {
    final text = state.rawText.toLowerCase();
    MessageIntent detected = MessageIntent.general;

    final keywords = {
      MessageIntent.greeting: ['hello', 'hi', 'hey', 'ki obostha', 'saalam', 'salam', 'kaise ho', 'namaste', 'vanakkam', 'namaskaram', 'kemon'],
      MessageIntent.request: ['help', 'please', 'request', 'deben', 'kar do', 'saahaita', 'udavi', 'sahayam'],
      MessageIntent.invitation: ['invite', 'dawat', 'party', 'birthday', 'wedding', 'dinner', 'dawat', 'shadi', 'amontron', 'alhaippu', 'aahvanam'],
      MessageIntent.apology: ['sorry', 'bhul', 'mistake', 'apologize', 'maaf', 'khed', 'mannikkavum', 'kshaminchandi'],
      MessageIntent.complaint: ['problem', 'issue', 'complain', 'bad', 'slow', 'waste', 'kharaap', 'shikayat', 'kurai', 'kuraipat'],
      MessageIntent.paymentReminder: ['payment', 'dues', 'bkash', 'bill', 'rent', 'due', 'taka', 'paise', 'baki', 'panaa', 'dabbulu'],
      MessageIntent.work: ['office', 'meeting', 'project', 'report', 'boss', 'deadline', 'task', 'update', 'kaaj', 'kam', 'velai'],
      MessageIntent.customerQuery: ['price', 'details', 'order', 'size', 'color', 'available', 'stock', 'daam', 'price?', 'vellai', 'dhara'],
      MessageIntent.boundary: ['call', 'disturb', 'boundary', 'block', 'personal', 'call korben na', 'message mat karo', 'thodarbu kollatha'],
      MessageIntent.appreciation: ['thank', 'awesome', 'great', 'nice', 'dhonnobad', 'shukriya', 'dhanyavaad', 'nandri', 'joss', 'shabaash'],
    };

    for (var entry in keywords.entries) {
      if (entry.value.any((kw) => text.contains(kw))) {
        detected = entry.key;
        break;
      }
    }

    state = state.copyWith(intent: detected);
    generateReplies();
  }

  void generateReplies() {
    final replies = TemplateEngine.generate(
      intent: state.intent,
      tone: state.tone,
      language: state.language,
    );
    state = state.copyWith(generatedReplies: replies);

    // Save to history automatically
    if (state.redactedText.isNotEmpty && replies.isNotEmpty && !state.redactedText.contains('Quick pack trigger')) {
      HistoryService.addHistoryItem(
        original: state.redactedText,
        replies: replies,
        intent: state.intent.name,
        tone: state.tone,
        language: state.language,
      );
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }
}

final replyProvider = StateNotifierProvider<ReplyNotifier, ReplyState>((ref) {
  return ReplyNotifier();
});

// Privacy Redaction Service
class PrivacyService {
  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );
  static final RegExp _bdPhoneRegex = RegExp(
    r'(?:\+?88)?01[3-9]\d{8}',
  );
  static final RegExp _indPhoneRegex = RegExp(
    r'(?:\+?91)?[6-9]\d{9}',
  );
  static final RegExp _otpRegex = RegExp(
    r'\b\d{4,6}\b',
  );

  static String redact(String input) {
    String output = input;
    output = output.replaceAll(_emailRegex, '[EMAIL REDACTED]');
    output = output.replaceAll(_bdPhoneRegex, '[PHONE REDACTED]');
    output = output.replaceAll(_indPhoneRegex, '[PHONE REDACTED]');
    
    final lower = input.toLowerCase();
    if (lower.contains('otp') || lower.contains('code') || lower.contains('verification') || lower.contains('pin') || lower.contains('কোড') || lower.contains('ओटीपी')) {
      output = output.replaceAll(_otpRegex, '[OTP REDACTED]');
    }
    
    return output;
  }
}

// Local Database Service using Hive
class HistoryService {
  static const String _boxName = 'reply_snap_box';
  static late Box _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  static bool isFirstLaunch() {
    return _box.get('first_launch', defaultValue: true);
  }

  static Future<void> setFirstLaunchCompleted() async {
    await _box.put('first_launch', false);
  }

  static List<Map<String, dynamic>> getHistory() {
    final List<dynamic>? raw = _box.get('history');
    if (raw == null) return [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addHistoryItem({
    required String original,
    required List<String> replies,
    required String intent,
    required String tone,
    required String language,
  }) async {
    final list = getHistory();
    if (list.isNotEmpty && list.first['original'] == original && list.first['tone'] == tone && list.first['language'] == language) {
      return;
    }
    
    list.insert(0, {
      'original': original.length > 100 ? '${original.substring(0, 100)}...' : original,
      'replies': replies,
      'intent': intent,
      'tone': tone,
      'language': language,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (list.length > 20) {
      list.removeLast();
    }
    await _box.put('history', list);
  }

  static List<String> getFavorites() {
    final List<dynamic>? raw = _box.get('favorites');
    if (raw == null) return [];
    return List<String>.from(raw);
  }

  static Future<void> toggleFavorite(String reply) async {
    final list = getFavorites();
    if (list.contains(reply)) {
      list.remove(reply);
    } else {
      list.insert(0, reply);
    }
    await _box.put('favorites', list);
  }

  static Future<void> clearHistory() async {
    await _box.delete('history');
  }

  static int getGenerationCount() {
    return _box.get('generation_count', defaultValue: 0);
  }

  static Future<void> incrementGenerationCount() async {
    final count = getGenerationCount();
    await _box.put('generation_count', count + 1);
  }

  static Future<void> resetGenerationCount() async {
    await _box.put('generation_count', 0);
  }

  static int getRegenerateCount() {
    return _box.get('regenerate_count', defaultValue: 0);
  }

  static Future<void> incrementRegenerateCount() async {
    final count = getRegenerateCount();
    await _box.put('regenerate_count', count + 1);
  }

  static Future<void> resetRegenerateCount() async {
    await _box.put('regenerate_count', 0);
  }
}

// Dynamic Template Engine with Natural Variation
class TemplateEngine {
  static final Random _random = Random();

  static List<String> generate({
    required MessageIntent intent,
    required String tone,
    required String language,
  }) {
    final List<String> openings = (_openings[language]?[tone] ?? _openings[language]?['Polite'] ?? []).cast<String>();
    final List<String> bodies = (_bodies[language]?[intent]?[tone] ?? _bodies[language]?[intent]?['Polite'] ?? []).cast<String>();
    final List<String> closings = (_closings[language]?[tone] ?? _closings[language]?['Polite'] ?? []).cast<String>();
    final List<String> emojis = _emojis[tone] ?? [''];

    List<String> results = [];
    final int variationCount = 3;

    for (int i = 0; i < variationCount; i++) {
      final opening = openings.isNotEmpty ? openings[_random.nextInt(openings.length)] : '';
      final body = bodies.isNotEmpty ? bodies[min(i, bodies.length - 1)] : '...';
      final closing = closings.isNotEmpty ? closings[_random.nextInt(closings.length)] : '';
      final emoji = emojis.isNotEmpty ? emojis[_random.nextInt(emojis.length)] : '';

      String combined = '$opening $body $closing $emoji'.replaceAll(RegExp(r'\s+'), ' ').trim();
      results.add(combined);
    }

    return results.toSet().toList(); // Ensure unique templates
  }

  // Curated templates library structure
  static const Map<String, Map<String, List<String>>> _openings = {
    'English': {
      'Polite': ['Thank you.', 'Hope you are doing well.', 'Greetings!'],
      'Friendly': ['Hey there!', 'What\'s up?', 'Hi!'],
      'Formal': ['Dear recipient,', 'Hope this message finds you well.', 'Greetings.'],
      'Direct': ['Look,', 'To be honest,', 'Here is the situation:'],
      'Funny': ['Haha, well!', 'Oh wow!', 'Guess what!'],
      'Polite No': ['Thank you for reaching out.', 'Thanks for the opportunity.', 'I appreciate the offer.'],
    },
    'Hindi': {
      'Polite': ['धन्यवाद।', 'आशा है आप सकुशल होंगे।', 'नमस्ते।'],
      'Friendly': ['अरे यार!', 'हेलो भाई!', 'कैसे हो दोस्त?'],
      'Formal': ['प्रिय महोदय/महोदया,', 'शुभकामनाएं।', 'आशा है यह संदेश आपको अच्छे स्वास्थ्य में मिलेगा।'],
      'Direct': ['देखो,', 'सीधी बात कहूं तो,', 'बात यह है कि:'],
      'Funny': ['अरे बॉस!', 'हाहा, देखो!', 'क्या बात है!'],
      'Polite No': ['पूछने के लिए धन्यवाद।', 'अवसर देने के लिए आभार।', 'मैं आपकी पेशकश की सराहना करता हूँ।'],
    },
    'Hinglish': {
      'Polite': ['Thanks.', 'Asha hai sab thik hoga.', 'Greetings!'],
      'Friendly': ['Hey yaar!', 'Kya chal raha hai?', 'Yo bro!'],
      'Formal': ['Dear Sir/Madam,', 'Hope all is well at your end.', 'Greetings.'],
      'Direct': ['Dekho,', 'Honestly bolu toh,', 'Asal baat yeh hai:'],
      'Funny': ['Haha, arey boss!', 'Oh bhai!', 'Guess kya hua!'],
      'Polite No': ['Puchne ke liye dhanyawad.', 'Offer ke liye shukriya.', 'Aapki offer acchi hai par,'],
    },
    'Bengali': {
      'Polite': ['ধন্যবাদ।', 'আশা করি ভালো আছেন।', 'নমস্কার / শুভকামনা।'],
      'Friendly': ['হেয়!', 'কেমন আছিস?', 'আরে ভাই!'],
      'Formal': ['সম্মানিত মহোদয়,', 'শুভেচ্ছা জানবেন।', 'আশা করি ভালো আছেন।'],
      'Direct': ['শুনুন,', 'সোজা কথায় বলি,', 'বিষয়টি হলো,'],
      'Funny': ['আরে ওস্তাদ!', 'খেলা তো জমে গেছে!', 'কাহিনী তো বুঝলাম!'],
      'Polite No': ['যোগাযোগের জন্য ধন্যবাদ।', 'জানানোর জন্য কৃতজ্ঞ।', 'আশা করি বুঝতে পারবেন।'],
    },
    'Banglish': {
      'Polite': ['Dhonnobad.', 'Asha kori bhalo achen.', 'Shubheccha niben.'],
      'Friendly': ['Hey!', 'Ki obostha bro?', 'Areh dost!'],
      'Formal': ['Dear Sir/Madam,', 'Shubheccha roilo.', 'Asha kori bhalo achen.'],
      'Direct': ['Shunon,', 'Soja kothay bolte gele,', 'Real kotha hocche,'],
      'Funny': ['Areh boss!', 'Khela toh jome gache!', 'Ami toh obak!'],
      'Polite No': ['Contact korar jonno thanks.', 'Janānor jonno dhonnobad.', 'Asha kori shujogti bujhte parben.'],
    },
    'Tamil': {
      'Polite': ['நன்றி.', 'நீங்கள் நலமாக இருக்கிறீர்கள் என்று நம்புகிறேன்.', 'வணக்கம்!'],
      'Friendly': ['ஹேய்!', 'என்ன பாஸ் விஷயம்?', 'ஹலோ நண்பா!'],
      'Formal': ['மதிப்பிற்குரிய ஐயா/அம்மா,', 'வணக்கம்.', 'இந்த செய்தி உங்களை நலமாக சென்றடையும் என நம்புகிறேன்.'],
      'Direct': ['பாருங்கள்,', 'உண்மையைச் சொல்வதானால்,', 'விஷயம் என்னவென்றால்:'],
      'Funny': ['ஹஹஹ, சரி!', 'ஓ வாவ்!', 'ஒரு நிமிடம் கேளுங்கள்!'],
      'Polite No': ['தொடர்பு கொண்டதற்கு நன்றி.', 'இந்த வாய்ப்பிற்கு நன்றி.', 'உங்கள் சலுகையை நான் மதிக்கிறேன், ஆனால்,'],
    },
    'Telugu': {
      'Polite': ['ధన్యవాదాలు.', 'మీరు బాగున్నారని ఆశిస్తున్నాను.', 'నమస్కారం!'],
      'Friendly': ['హేయ్!', 'ఏంటి సంగతులు?', 'హలో ఫ్రెండ్!'],
      'Formal': ['గౌరవనీయులైన సర్/మేడమ్,', 'నమస్కారం.', 'మీరు బాగున్నారని ఆశిస్తున్నాము.'],
      'Direct': ['చూడండి,', 'నిజం చెప్పాలంటే,', 'విషయం ఏమిటంటే:'],
      'Funny': ['హహా, అరే బాస్!', 'ఓ వావ్!', 'ఏంటో ఊహించండి!'],
      'Polite No': ['సంప్రదించినందుకు ధన్యవాదాలు.', 'అవకాశం ఇచ్చినందుకు కృతజ్ఞతలు.', 'మీ ప్రతిపాదన బాగుంది కానీ,'],
    }
  };

  static const Map<String, Map<String, List<String>>> _closings = {
    'English': {
      'Polite': ['Have a great day.', 'Best regards,', 'Warmly,'],
      'Friendly': ['Talk soon!', 'Catch you later!', 'Cheers!'],
      'Formal': ['Sincerely,', 'Respectfully,', 'Looking forward to hearing from you.'],
      'Direct': ['Let me know.', 'That\'s my stance.', 'Thanks.'],
      'Funny': ['Don\'t take it seriously!', 'Haha, just kidding!', 'No pressure!'],
      'Polite No': ['Wish you all the best.', 'Maybe next time.', 'Thanks again.'],
    },
    'Hindi': {
      'Polite': ['आपका दिन शुभ हो।', 'सादर,', 'शुभकामनाएं।'],
      'Friendly': ['जल्दी बात करते हैं!', 'फिर मिलेंगे!', 'बाय!'],
      'Formal': ['भवदीय,', 'आपके उत्तर की प्रतीक्षा में।', 'सधन्यवाद।'],
      'Direct': ['मुझे बताएं।', 'यही मेरा निर्णय है।', 'धन्यवाद।'],
      'Funny': ['दिल पर मत लेना भाई!', 'हाहा, बस मजाक था!', 'कोई लोड नहीं है!'],
      'Polite No': ['आपको बहुत-बहुत शुभकामनाएं।', 'शायद अगली बार।', 'पुनः धन्यवाद।'],
    },
    'Hinglish': {
      'Polite': ['Apka din accha rahe.', 'Regards,', 'Shubhkamnaye.'],
      'Friendly': ['Baat karte hain baad me!', 'Milte hain jaldi!', 'Bye!'],
      'Formal': ['Sincerely,', 'Apke reply ka wait rahega.', 'Warm regards.'],
      'Direct': ['Bata dena mujhe.', 'Yahi final hai.', 'Thanks.'],
      'Funny': ['Serious mat lena yaar!', 'Haha, chill maro!', 'No tension!'],
      'Polite No': ['Aapko best of luck.', 'Phir kabhi koshish karenge.', 'Thanks again.'],
    },
    'Bengali': {
      'Polite': ['ভালো থাকবেন।', 'ধন্যবাদ সহ,', 'বিদায়।'],
      'Friendly': ['কথা হবে!', 'দেখা হবে শিগগিরই।', 'টাটা!'],
      'Formal': ['বিনীত,', 'আপনার উত্তরের অপেক্ষায় রইলাম।', 'ধন্যবাদান্তে।'],
      'Direct': ['এটাই আমার বক্তব্য।', 'আশা করি ক্লিয়ার।', 'জানাবেন।'],
      'Funny': ['বেশি পেইন নিয়েন না!', 'দুষ্টুমি করলাম আরকি!', 'মজা লন!'],
      'Polite No': ['শুভকামনা রইল।', 'আশা করি পরেরবার সুযোগ হবে।', 'ভালো থাকবেন।'],
    },
    'Banglish': {
      'Polite': ['Bhalo thakben.', 'Dhonnobad sho,', 'Abar kotha hobe.'],
      'Friendly': ['Kotha hobe!', 'Dekha hobe shiggori.', 'Tata!'],
      'Formal': ['Binit,', 'Apnar reply-er opekkha roilam.', 'Regards.'],
      'Direct': ['Etai final.', 'Asha kori clear.', 'Janien.'],
      'Funny': ['Chill thakun!', 'Just fun korlam!', 'Enjoy koren!'],
      'Polite No': ['Shubhokamona roilo.', 'Asha kori next time hobe.', 'Take care.'],
    },
    'Tamil': {
      'Polite': ['நல்ல நாளாக அமையட்டும்.', 'அன்புடன்,', 'நல்வாழ்த்துகள்.'],
      'Friendly': ['சீக்கிரம் பேசுவோம்!', 'அப்புறம் பார்ப்போம்!', 'டாடா!'],
      'Formal': ['இப்படிக்கு,', 'உங்கள் பதிலுக்காக காத்திருக்கிறேன்.', 'நன்றியுடன்.'],
      'Direct': ['எனக்குத் தெரியப்படுத்துங்கள்.', 'இதுவே எனது முடிவு.', 'நன்றி.'],
      'Funny': ['சீரியஸாக எடுத்துக்கொள்ள வேண்டாம்!', 'ஹஹஹ, சும்மா விளையாட்டுக்குத்தான்!', 'நோ டென்ஷன்!'],
      'Polite No': ['உங்களுக்கு எனது வாழ்த்துகள்.', 'அடுத்த முறை பார்ப்போம்.', 'மீண்டும் நன்றி.'],
    },
    'Telugu': {
      'Polite': ['మంచి రోజు అవ్వాలి.', 'భవదీయుడు,', 'శుభాకాంక్షలు.'],
      'Friendly': ['త్వరలో మాట్లాడదాం!', 'మళ్ళీ కలుద్దాం!', 'బాయ్!'],
      'Formal': ['భవదీయుడు,', 'మీ సమాధానం కోసం ఎదురుచూస్తున్నాము.', 'ధన్యవాదాలు.'],
      'Direct': ['నాకు తెలియజేయండి.', 'ఇదే నా నిర్ణయం.', 'థాంక్స్.'],
      'Funny': ['సీరియస్ గా తీసుకోకండి!', 'హహా, ఊరికే సరదాకి!', 'టెన్షన్ లేదు!'],
      'Polite No': ['మీకు శుభం కలగాలని ఆశిస్తున్నాను.', 'బహుశా వచ్చే సారి.', 'మరోసారి ధన్యవాదాలు.'],
    }
  };

  static const Map<String, List<String>> _emojis = {
    'Polite': ['😊', '🙏', '✨'],
    'Friendly': ['👍', '🥳', '😎', '🔥'],
    'Formal': ['🤝', '💼', '✍️'],
    'Direct': ['.', '!', '👍'],
    'Funny': ['😂', '🤪', '😜', '🍿'],
    'Polite No': ['🙏', '🌸', '👍'],
  };

  static const Map<String, Map<MessageIntent, Map<String, List<String>>>> _bodies = {
    'English': {
      MessageIntent.greeting: {
        'Polite': ['It\'s been a while. How are things going?', 'It was wonderful to receive your message.'],
        'Friendly': ['Hey! How\'s it going?', 'Good to hear from you! How have you been?'],
        'Formal': ['Pleasure to connect with you. Hope all is well.', 'Good day. I trust you are doing fine.'],
        'Direct': ['Yes, how can I help you?', 'Hello, please let me know your query.'],
        'Funny': ['Hey superstar! What\'s the good word?', 'Look who decided to drop by!'],
        'Polite No': ['I received your message. I am quite tied up at the moment.', 'Thanks. Cannot talk right now.'],
      },
      MessageIntent.request: {
        'Polite': ['I will certainly do my best to assist you with this.', 'Let me look into this request and get back to you.'],
        'Friendly': ['Sure, I can handle that for you!', 'No problem at all! Let see what I can do.'],
        'Formal': ['Your request has been logged. We will address it immediately.', 'I am processing your request and will prioritize it.'],
        'Direct': ['I will work on this. Stand by.', 'Will do. You will have it on time.'],
        'Funny': ['You\'re putting the lazy genius to work? Alright then!', 'I can do that, but what\'s in it for me?'],
        'Polite No': ['Regrettably, I cannot fulfill this request at this time.', 'Due to other commitments, I must decline this request.'],
      },
      MessageIntent.invitation: {
        'Polite': ['Thank you for the kind invite. I will do my best to attend.', 'I would love to come. Thank you for thinking of me.'],
        'Friendly': ['Definitely coming! Can\'t wait to celebrate!', 'Count me in! It\'s going to be awesome.'],
        'Formal': ['Thank you for your gracious invitation. I will confirm my schedule.', 'I am honored by the invitation and intend to attend.'],
        'Direct': ['Sounds good. I will be there.', 'Accepting the invitation. See you then.'],
        'Funny': ['If there is free food, you don\'t even need to ask!', 'I\'ll be there to crash the party, don\'t worry!'],
        'Polite No': ['I have a prior commitment, so I won\'t be able to make it.', 'Unfortunately, I cannot attend due to scheduling conflicts.'],
      },
      MessageIntent.apology: {
        'Polite': ['I sincerely apologize for the misunderstanding.', 'Please accept my apologies for the inconvenience caused.'],
        'Friendly': ['Sorry about that! My bad.', 'Oops, didn\'t mean to do that. Hope we\'re good!'],
        'Formal': ['We deeply regret the error and are taking measures to fix it.', 'Please accept our formal apology for this lapse.'],
        'Direct': ['My mistake. I will correct it right away.', 'Apologies. It will not happen again.'],
        'Funny': ['Please don\'t put me in time-out! I\'m sorry!', 'I make mistakes to keep life interesting. Sorry!'],
        'Polite No': ['I apologize, but this is the final decision on the matter.', 'I am sorry, but I stand by my action given the context.'],
      },
      MessageIntent.complaint: {
        'Polite': ['This is unfortunate. I will coordinate to get it sorted out.', 'We regret that you had this experience. Fixing it now.'],
        'Friendly': ['Man, that\'s frustrating! Let me see what I can do.', 'I feel you, that\'s not right. Let me check.'],
        'Formal': ['We are launching an investigation into this matter immediately.', 'Your complaint has been forwarded to senior management.'],
        'Direct': ['This is unacceptable. I am ordering an immediate correction.', 'Complaint noted. Immediate action is being taken.'],
        'Funny': ['Well, that went spectacularly wrong! Let\'s fix it.', 'Who broke the machine again? Let me find out.'],
        'Polite No': ['We note your dissatisfaction, but we must adhere to our policy.', 'Thank you for the report, but no further revisions are possible.'],
      },
      MessageIntent.paymentReminder: {
        'Polite': ['Just a gentle reminder regarding the outstanding payment.', 'Could you please check on the status of this payment?'],
        'Friendly': ['Hey, just checking if you could send over the payment today.', 'Hope you can clear that invoice when you get a chance!'],
        'Formal': ['Please find attached the invoice for services rendered. Awaiting settlement.', 'This is a formal request for payment on invoice #104.'],
        'Direct': ['Please pay the outstanding balance. Details are provided above.', 'Payment is due today. Please clear it.'],
        'Funny': ['Money makes the world go round! Send it over!', 'I love working, but I love getting paid even more!'],
        'Polite No': ['Unfortunately, we must halt work until the payment is cleared.', 'As per terms, no extension can be granted on this bill.'],
      },
      MessageIntent.work: {
        'Polite': ['I am currently working on the report and will share it shortly.', 'The meeting agenda is ready. We will start on time.'],
        'Friendly': ['On it right now! Will send it over soon, chill!', 'Let me review this one more time before boss sees it.'],
        'Formal': ['Every effort is being made to meet the project deadline.', 'The minutes of today\'s meeting will be circulated via email.'],
        'Direct': ['Work in progress. Will meet the deadline.', 'Report is ready. Please check your inbox.'],
        'Funny': ['Working hard or hardly working? Definitely the former!', 'If only coding paid in pizza! Onto it now!'],
        'Polite No': ['I cannot take on this task due to my current bandwidth.', 'Unable to attend the meeting today due to urgent conflicts.'],
      },
      MessageIntent.customerQuery: {
        'Polite': ['The pricing and specifications have been sent to your inbox.', 'This item is currently in stock and ready to ship.'],
        'Friendly': ['Super affordable! Inbox me to place your order right now!', 'We have many colors and sizes. Which one do you want?'],
        'Formal': ['Please find the catalogue and delivery terms attached.', 'Thank you for your query. The item ships within 3 business days.'],
        'Direct': ['The price is \$12. Cash on delivery is available.', 'Stock is limited. Share name and number to order.'],
        'Funny': ['You won\'t find a better deal even if you try! Get it now!', 'High quality, low price. Win-win situation!'],
        'Polite No': ['We regret to inform you that this item is discontinued.', 'Unfortunately, no discounts are available at this time.'],
      },
      MessageIntent.boundary: {
        'Polite': ['Please refrain from contacting me outside of office hours.', 'I would prefer to keep our conversations professional.'],
        'Friendly': ['Hey, let\'s keep this strictly business, alright?', 'Not really comfortable sharing my personal details, thanks.'],
        'Formal': ['Please utilize official channels for all future communication.', 'This line of questioning is outside the scope of our agreement.'],
        'Direct': ['Please do not call or text me again.', 'I wish to end this conversation here.'],
        'Funny': ['Are you writing a biography about me? Let\'s stop here.', 'Boundary warning! Keep it simple, boss!'],
        'Polite No': ['Thank you, but I do not wish to discuss this further.', 'Any further unsolicited messages will result in a block.'],
      },
      MessageIntent.appreciation: {
        'Polite': ['Thank you for your kind words. It is highly appreciated.', 'I am grateful for your support and feedback.'],
        'Friendly': ['Thanks a lot! You are the best!', 'Much love! You rock!'],
        'Formal': ['We appreciate your support and look forward to serving you again.', 'Thank you for your business and trust in our services.'],
        'Direct': ['Thank you. Your help was valuable.', 'Grateful for this.'],
        'Funny': ['Keep the compliments coming, I love it!', 'Award-winning response! Thanks!'],
        'Polite No': ['Thank you for the compliment, though I must decline the offer.', 'Much appreciated, but my decision remains unchanged.'],
      },
      MessageIntent.general: {
        'Polite': ['I understand the situation. Thank you for updating me.', 'Okay, I will contact you again shortly.'],
        'Friendly': ['Got it! Talk to you later then.', 'Alright, cool. Catch you later.'],
        'Formal': ['Your message has been received. We will update you in due course.', 'Thank you for sharing this information.'],
        'Direct': ['Understood. Next update will follow shortly.', 'Received. Taking action.'],
        'Funny': ['I get the story, but who\'s buying the coffee?', 'Haha, excellent! Tell me more.'],
        'Polite No': ['Thanks for the message, but I have no comments on this.', 'Sorry, I am not in a position to comment on this.'],
      },
    },
    'Hindi': {
      MessageIntent.greeting: {
        'Polite': ['बहुत दिनों बाद बात हुई। सब कैसा चल रहा है?', 'आपका संदेश पाकर खुशी हुई।'],
        'Friendly': ['और भाई, क्या हाल है?', 'क्या चल रहा है दोस्त? बहुत दिनों बाद याद किया!'],
        'Formal': ['आपसे संपर्क करके प्रसन्नता हुई। आशा है सब ठीक होगा।', 'नमस्ते। मैं उम्मीद करता हूँ कि आप सकुशल होंगे।'],
        'Direct': ['जी बताएं, क्या बात है?', 'नमस्ते, कृपया अपनी समस्या बताएं।'],
        'Funny': ['और महाराज! क्या खबर है?', 'कौन आ गया भाई! क्या सेवा करें आपकी?'],
        'Polite No': ['संदेश के लिए धन्यवाद। मैं अभी थोड़ा व्यस्त हूँ।', 'नमस्ते। अभी बात नहीं कर पाऊंगा।'],
      },
      MessageIntent.request: {
        'Polite': ['मैं इसके लिए ज़रूर प्रयास करूँगा। मुझे थोड़ा समय दें।', 'आपकी समस्या को सुलझाने की पूरी कोशिश की जाएगी।'],
        'Friendly': ['अरे बिल्कुल भाई, मैं कर दूंगा!', 'कोई बात नहीं दोस्त, मैं देखता हूँ क्या कर सकता हूँ।'],
        'Formal': ['आपका अनुरोध दर्ज कर लिया गया है। हम जल्द ही कार्रवाई करेंगे।', 'मैं प्राथमिकता के आधार पर आपके अनुरोध पर काम कर रहा हूँ।'],
        'Direct': ['इस पर काम करूँगा। थोड़ा इंतजार करें।', 'ठीक है, समय पर काम हो जाएगा।'],
        'Funny': ['मुझ जैसे आलसी से काम करवाओगे? चलो ठीक है!', 'काम तो हो जाएगा, लेकिन बदले में समोसा कब खिलाओगे?'],
        'Polite No': ['खेद है, मैं अभी इस काम में मदद नहीं कर पाऊंगा।', 'व्यस्तता के कारण मुझे इस अनुरोध को अस्वीकार करना होगा।'],
      },
      MessageIntent.invitation: {
        'Polite': ['आमंत्रण के लिए धन्यवाद। मैं आने का पूरा प्रयास करूँगा।', 'न्योते के लिए बहुत-बहुत आभार। ज़रूर आऊंगा।'],
        'Friendly': ['पक्का आऊंगा भाई! पार्टी मिस नहीं कर सकता!', 'मुझे भी शामिल समझो! धमाल मचाएंगे!'],
        'Formal': ['सदय निमंत्रण के लिए धन्यवाद। मैं समय पर पहुँचने का प्रयास करूँगा।', 'कार्यक्रम में आमंत्रित करने के लिए मैं आपका आभारी हूँ।'],
        'Direct': ['ठीक है, मैं आ जाऊंगा।', 'निमंत्रण स्वीकार है। मिलते हैं।'],
        'Funny': ['मुफ्त का खाना हो तो पूछने की जरूरत ही नहीं है!', 'पार्टी में तबाही मचाने के लिए मैं आ रहा हूँ!'],
        'Polite No': ['पहले से कोई काम होने के कारण मैं उपस्थित नहीं हो पाऊंगा।', 'असुविधा के लिए खेद है, लेकिन व्यस्तता के कारण मैं नहीं आ सकूँगा।'],
      },
      MessageIntent.apology: {
        'Polite': ['गलतफहमी के लिए मैं ईमानदारी से माफी चाहता हूँ।', 'हुई असुविधा के लिए कृपया मेरी क्षमा स्वीकार करें।'],
        'Friendly': ['अरे यार, गलती हो गई! सॉरी!', 'अरे गलती से मिस्टेक हो गया भाई! अब गुस्सा थूक दो!'],
        'Formal': ['इस त्रुटि के लिए हमें गहरा खेद है। हम इसे सुधारने के उपाय कर रहे हैं।', 'कृपया सेवा में हुई इस असुविधा के लिए हमारी औपचारिक क्षमा स्वीकार करें।'],
        'Direct': ['मेरी गलती है। मैं इसे तुरंत ठीक कर देता हूँ।', 'माफी चाहता हूँ। दोबारा ऐसा नहीं होगा।'],
        'Funny': ['मुर्गा बन जाऊं क्या अब? गलती हो गई भाई!', 'इंसान हूँ यार, गलती तो हो ही जाती है! माफ कर दो!'],
        'Polite No': ['मैं माफी मांगता हूँ, लेकिन इस मामले पर यही अंतिम निर्णय है।', 'खेद है, लेकिन परिस्थितियों को देखते हुए मेरा निर्णय सही था।'],
      },
      MessageIntent.complaint: {
        'Polite': ['यह दुर्भाग्यपूर्ण है। मैं इसे सुलझाने का प्रयास करता हूँ।', 'असुविधा के लिए खेद है। हम इसे तुरंत ठीक कर रहे हैं।'],
        'Friendly': ['यार, ये तो सच में गुस्सा दिलाने वाली बात है! देखता हूँ क्या हो सकता है।', 'मुझे दुख है दोस्त, यह सही नहीं हुआ। मैं चेक करता हूँ।'],
        'Formal': ['हम इस मामले की तुरंत जांच शुरू कर रहे हैं।', 'आपकी शिकायत को आगे वरिष्ठ प्रबंधन के पास भेज दिया गया है।'],
        'Direct': ['यह स्वीकार्य नहीं है। मैं तुरंत सुधार का आदेश दे रहा हूँ।', 'शिकायत दर्ज कर ली गई है। तत्काल कार्रवाई की जा रही है।'],
        'Funny': ['ये तो गजब रायता फैल गया! चलो इसे समेटते हैं।', 'अब किसने काम बिगाड़ दिया? मैं पता लगाता हूँ।'],
        'Polite No': ['हम आपकी नाराजगी समझते हैं, लेकिन हमें नियमों का पालन करना होगा।', 'शिकायत के लिए धन्यवाद, लेकिन इसमें आगे कोई सुधार संभव नहीं है।'],
      },
      MessageIntent.paymentReminder: {
        'Polite': ['बकाया भुगतान के संबंध में एक छोटा सा अनुस्मारक।', 'क्या आप कृपया भुगतान की स्थिति की जांच कर सकते हैं?'],
        'Friendly': ['भाई, थोड़ा पेमेंट आज ट्रांसफर कर दो न!', 'यार, टाइम पर बिल क्लियर कर दो तो अच्छा रहेगा!'],
        'Formal': ['कृपया सेवाओं के लिए बकाया भुगतान जल्द से जल्द चुकाने का कष्ट करें।', 'यह आपके इनवॉइस के भुगतान के संबंध में एक औपचारिक अनुस्मारक है।'],
        'Direct': ['कृपया बकाया राशि का भुगतान करें। विवरण ऊपर दिए गए हैं।', 'भुगतान आज ही करना है। कृपया क्लियर करें।'],
        'Funny': ['बाबू भैया, सबसे बड़ा रुपैया! जल्दी पेमेंट भेज दो!', 'काम तो प्यारा है, लेकिन दाम उससे भी ज्यादा प्यारा है! चुका दो!'],
        'Polite No': ['खेद है, भुगतान पूरा होने तक हम आगे काम नहीं कर पाएंगे।', 'नियमों के अनुसार, इस बिल के भुगतान में कोई छूट नहीं दी जा सकती।'],
      },
      MessageIntent.work: {
        'Polite': ['मैं अभी रिपोर्ट पर काम कर रहा हूँ और जल्द ही साझा करूँगा।', 'मीटिंग का एजेंडा तैयार है। हम समय पर शुरू करेंगे।'],
        'Friendly': ['अभी काम पर लगा हूँ भाई! जल्दी भेजता हूँ, चिल!', 'बॉस को दिखाने से पहले एक बार खुद चेक कर लूं यार।'],
        'Formal': ['परियोजना की समय सीमा को पूरा करने के लिए हर संभव प्रयास किया जा रहा है।', 'आज की बैठक का विवरण ईमेल द्वारा भेज दिया जाएगा।'],
        'Direct': ['काम जारी है। समय सीमा के भीतर पूरा हो जाएगा।', 'रिपोर्ट तैयार है। अपना इनबॉक्स चेक करें।'],
        'Funny': ['नौकरी की तो मजबूरी है, वरना चिल करना किसे पसंद नहीं!', 'अगर कोड करने के बदले पिज़्ज़ा मिलता तो क्या बात होती! काम चालू है!'],
        'Polite No': ['व्यस्तता के कारण मैं इस नए काम की जिम्मेदारी नहीं ले पाऊंगा।', 'अति आवश्यक काम होने के कारण आज मीटिंग में शामिल नहीं हो सकूँगा।'],
      },
      MessageIntent.customerQuery: {
        'Polite': ['कीमत और अन्य विवरण आपके इनबॉक्स में भेज दिए गए हैं।', 'यह आइटम अभी स्टॉक में उपलब्ध है और भेजा जा सकता है।'],
        'Friendly': ['बहुत ही कम दाम में है भाई! ऑर्डर करने के लिए इनबॉक्स करो!', 'हमारे पास बहुत सारे कलर और साइज हैं। आपको कौन सा चाहिए?'],
        'Formal': ['कृपया संलग्न सूची और वितरण शर्तें देखें।', 'पूछताछ के लिए धन्यवाद। आइटम ३ कार्य दिवसों के भीतर भेज दिया जाएगा।'],
        'Direct': ['कीमत १,२०० रुपये है। कैश ऑन डिलीवरी उपलब्ध है।', 'स्टॉक सीमित है। ऑर्डर के लिए नाम और नंबर भेजें।'],
        'Funny': ['कीमत सुन के सदमा मत खाना, क्वालिटी एकदम धांसू है!', 'सस्ता और सबसे अच्छा! आज ही ले जाओ बॉस!'],
        'Polite No': ['खेद है कि यह आइटम अब उपलब्ध नहीं है और बंद हो चुका है।', 'दुर्भाग्य से, इस समय कोई छूट उपलब्ध नहीं है।'],
      },
      MessageIntent.boundary: {
        'Polite': ['कृपया मुझे ऑफिस के समय के बाद कॉल या मैसेज न करें।', 'मैं अपनी बातचीत को केवल पेशेवर रखना पसंद करूँगा।'],
        'Friendly': ['भाई, काम की बात करो तो अच्छा है, फालतू बातें नहीं।', 'मैं अपनी पर्सनल लाइफ के बारे में बात नहीं करना चाहता, धन्यवाद।'],
        'Formal': ['भविष्य के संचार के लिए कृपया केवल आधिकारिक माध्यमों का उपयोग करें।', 'यह विषय हमारे समझौते के कार्यक्षेत्र से बाहर है।'],
        'Direct': ['कृपया मुझे दोबारा फोन या संदेश न भेजें।', 'मैं इस बातचीत को यहीं समाप्त करना चाहता हूँ।'],
      },
      MessageIntent.appreciation: {
        'Polite': ['आपके अच्छे शब्दों के लिए धन्यवाद। इसकी बहुत सराहना की जाती है।', 'मैं आपके सहयोग और प्रतिक्रिया के लिए आभारी हूँ।'],
        'Friendly': ['बहुत-बहुत धन्यवाद भाई! तुम कमाल हो!', 'अरे थैंक्स दोस्त! तुम तो हमेशा साथ देते हो!'],
        'Formal': ['हम आपकी प्रतिक्रिया की सराहना करते हैं और आपकी सेवा के लिए तत्पर हैं।', 'हम पर विश्वास और समर्थन दिखाने के लिए आपका धन्यवाद।'],
        'Direct': ['धन्यवाद। आपकी मदद बहुत कीमती थी।', 'आभार।'],
        'Funny': ['तारीफ करते रहो भाई, अच्छा लगता है!', 'तारीफ सुन के छाती चौड़ी हो गई बॉस! समोसा खिलाओ अब!'],
        'Polite No': ['प्रशंसा के लिए धन्यवाद, लेकिन मैं इस प्रस्ताव को स्वीकार नहीं कर पाऊंगा।', 'सराहना के लिए आभार, लेकिन मेरा निर्णय अपरिवर्तित रहेगा।'],
      },
      MessageIntent.general: {
        'Polite': ['मैं स्थिति समझता हूँ। जानकारी देने के लिए धन्यवाद।', 'ठीक है। मैं जल्द ही आपसे दोबारा संपर्क करूँगा।'],
        'Friendly': ['समझ गया भाई! बाद में बात करते हैं।', 'ठीक है दोस्त, चिल! बाद में मिलता हूँ।'],
        'Formal': ['आपका संदेश प्राप्त हो गया है। हम समय आने पर आपको सूचित करेंगे।', 'जानकारी साझा करने के लिए आपका धन्यवाद।'],
        'Direct': ['समझ गया। अगला अपडेट जल्द ही मिलेगा।', 'प्राप्त हुआ। कार्रवाई की जा रही है।'],
        'Funny': ['कहानी तो समझ आ गई, पर चाय कौन पिलाएगा?', 'हाहा, बहुत बढ़िया! आगे बताओ क्या खबर है?'],
        'Polite No': ['संदेश के लिए धन्यवाद, लेकिन इस बारे में मेरी कोई राय नहीं है।', 'खेद है, मैं अभी इस विषय पर कुछ नहीं कह सकता।'],
      },
    },
    'Hinglish': {
      MessageIntent.greeting: {
        'Polite': ['Bohat dino baad baat hui. Kaisa chal raha hai sab?', 'Apka message milne par accha laga.'],
        'Friendly': ['Aur bhai, kya haal chal?', 'Kya chal raha hai dost? Kafi time baad yaad kiya!'],
        'Formal': ['Aapse connect hokar khushi hui. Asha hai sab thik hoga.', 'Namaste. Aasha hai aap thik honge.'],
        'Direct': ['Ji boliye, kya baat hai?', 'Namaste, please apna query batayein.'],
        'Funny': ['Aur boss, kya chal raha hai?', 'Kaun aa gaya bhai! Kya seva karein aapki?'],
        'Polite No': ['Message ke liye thanks. Mai abhi thoda busy hu.', 'Hi. Abhi baat nahi ho payegi.'],
      },
      MessageIntent.request: {
        'Polite': ['Mai iske liye jarur koshish karunga. Thoda time de.', 'Apki problem solve karne ki puri koshish rahegi.'],
        'Friendly': ['Arey bilkul bhai, mai kar dunga!', 'Koi baat nahi dost, mai dekhta hu kya ho sakta hai.'],
        'Formal': ['Apka request register ho chuka hai. Hum jald hi action lenge.', 'Mai priority basis par apke request par kaam kar raha hu.'],
        'Direct': ['Is par kaam karunga. Thoda wait karein.', 'Thik hai, time par kaam ho jayega.'],
        'Funny': ['Mujh jaise lazy insaan se kaam karvaoge? Chalo thik hai!', 'Kaam toh ho jayega, but badle me biryani kab khilaoge?'],
        'Polite No': ['Sorry yaar, mai abhi isme help nahi kar paunga.', 'Busy hone ke karan mujhe is request ko decline karna hoga.'],
      },
      MessageIntent.invitation: {
        'Polite': ['Invite karne ke liye thanks. Aane ki puri koshish rahegi.', 'Dawat ke liye shukriya. Jarur aunga.'],
        'Friendly': ['Pakka aunga bhai! Party miss nahi kar sakta!', 'Mujhe bhi shamil samjho! Dhamal machayenge!'],
        'Formal': ['Invitation ke liye dhanyawad. Mai samay par pahunchne ki koshish karunga.', 'Event me invite karne ke liye mai apka aabhari hu.'],
        'Direct': ['Thik hai, mai aa jaunga.', 'Invitation accept kiya. Milte hain.'],
        'Funny': ['Free ka khana ho toh puchne ki jarurat hi nahi hai!', 'Party crash karne ke liye mai aa raha hu!'],
        'Polite No': ['Pehle se koi aur kaam hone ki wajah se mai nahi aa paunga.', 'Sorry, busy schedule ke karan mai join nahi kar paunga.'],
      },
      MessageIntent.apology: {
        'Polite': ['Galatfehmi ke liye mai sincerely sorry chahta hu.', 'Hui dikkat ke liye please meri apology accept karein.'],
        'Friendly': ['Arey yaar, galti ho gayi! Sorry!', 'Arey galti se mistake ho gaya bhai! Ab gussa thuk do!'],
        'Formal': ['Is error ke liye hume khed hai. Hum ise thik kar rahe hain.', 'Service me hui dikkat ke liye please humari apology accept karein.'],
        'Direct': ['Meri galti hai. Mai ise turant thik kar deta hu.', 'Sorry. Dobara aisa nahi hoga.'],
        'Funny': ['Kan pakad ke sorry bolu kya ab? Galti ho gayi bhai!', 'Insaan hu yaar, galti toh ho hi jati hai! Maaf kar do!'],
        'Polite No': ['Mai sorry bolta hu, but is matter par yahi mera final decision hai.', 'Sorry, but situation ke hisab se mera decision thik tha.'],
      },
      MessageIntent.complaint: {
        'Polite': ['Yeh unfortunate hai. Mai ise solve karne ki koshish karta hu.', 'Sirasari dikkat ke liye sorry. Hum ise turant thik kar rahe hain.'],
        'Friendly': ['Yaar, yeh toh sach me gussa dilane wali baat hai! Dekhta hu kya ho sakta hai.', 'Mujhe dukh hai dost, yeh sahi nahi hua. Mai check karta hu.'],
        'Formal': ['Hum is matter ki turant enquiry shuru kar rahe hain.', 'Apki complaint ko senior management ke paas bhej diya gaya hai.'],
        'Direct': ['Yeh accept nahi kiya ja sakta. Mai turant action lene ko bolta hu.', 'Complaint note kar li hai. Jald hi action liya jayega.'],
        'Funny': ['Yeh toh bada locha ho gaya! Chalo ise thik karte hain.', 'Ab kisne kaam bigad diya? Mai pata lagata hu.'],
        'Polite No': ['Hum apki dikkat samajhte hain, but hume rules follow karne honge.', 'Complaint ke liye thanks, but isme ab koi change possible nahi hai.'],
      },
      MessageIntent.paymentReminder: {
        'Polite': ['Due payment ke baare me ek chota sa reminder.', 'Kya aap please payment status check kar sakte hain?'],
        'Friendly': ['Bhai, thoda payment aaj transfer kar do na!', 'Yaar, time par bill clear kar do toh accha rahega!'],
        'Formal': ['Please invoice ke payments jald se jald clear karne ki koshish karein.', 'Yeh payment ke sambandh me ek formal reminder hai.'],
        'Direct': ['Please due payment clear karein. Bank details upar hain.', 'Payment aaj hi clear karni hai. Please kar do.'],
        'Funny': ['Paisa bolta hai boss! Jaldi se bhej do!', 'Kaam toh accha hai, but dam usse bhi pyara hai! De do!'],
        'Polite No': ['Sorry, payment complete hone tak hum aage kaam nahi kar payenge.', 'Rules ke mutabik, is payment me koi extension nahi mil sakta.'],
      },
      MessageIntent.work: {
        'Polite': ['Mai abhi report par kaam kar raha hu aur jald hi share karunga.', 'Meeting ka agenda ready hai. Time par shuru karenge.'],
        'Friendly': ['Kaam par laga hu bhai! Jaldi bhejta hu, chill!', 'Boss ko dikhane se pehle ek baar khud check kar lu yaar.'],
        'Formal': ['Project deadline meet karne ke liye pura try kiya ja raha hai.', 'Aaj ki meeting ke minutes email kar diye jayenge.'],
        'Direct': ['Work in progress. Deadline tak ho jayega.', 'Report ready hai. Apna mail check karein.'],
        'Funny': ['Naukri ki toh majboori hai, kya karein!', 'Agar coding ke badle pizza milta toh kya baat hoti! Kaam shuru hai!'],
        'Polite No': ['Bandwidth kam hone ke karan mai yeh naya kaam nahi le paunga.', 'Urgent kaam ki wajah se aaj meeting join nahi kar paunga.'],
      },
      MessageIntent.customerQuery: {
        'Polite': ['Price aur details apke inbox me send kar di gayi hain.', 'Yeh item abhi stock me hai aur deliver kiya ja sakta hai.'],
        'Friendly': ['Bohat sasta hai bhai! Order karne ke liye inbox karo!', 'Humare paas bohat saare colors aur sizes hain. Konsa chahiye batayein?'],
        'Formal': ['Please attached price list aur delivery terms dekhye.', 'Query ke liye thanks. Item 3 working days me ship ho jayega.'],
        'Direct': ['Price 1,200 rupees hai. Cash on delivery available hai.', 'Stock limited hai. Order ke liye name aur number send karein.'],
        'Funny': ['Price sunkar shock mat hona, quality ekdum top class hai!', 'Best and cheapest! Aaj hi le jao boss!'],
        'Polite No': ['Sorry, yeh item ab out of stock hai aur aage nahi aayega.', 'Sorry, is time koi discount available nahi hai.'],
      },
      MessageIntent.boundary: {
        'Polite': ['Please mujhe office hours ke baad call ya message na karein.', 'Mai apni conversation ko professional rakhna pasand karunga.'],
        'Friendly': ['Bhai, kaam ki baat karo toh thik hai, faltu baatein nahi.', 'Mai apni personal life ke baare me baat nahi karna chahta, thanks.'],
        'Formal': ['Future communication ke liye please official medium use karein.', 'Yeh topic humare agreement ke scope se bahar hai.'],
        'Direct': ['Please mujhe dobara call ya message mat karna.', 'Mai is conversation ko yahi khatam karna chahta hu.'],
        'Funny': ['Kya mere upar biography likh rahe ho? Chal ab bas kar.', 'Boundary cross karoge toh red card milega boss!'],
        'Polite No': ['Thanks, but mai is baare me aage baat nahi karna chahta.', 'Baar-baar faltu messages karne par mai block karne par majboor ho jaunga.'],
      },
      MessageIntent.appreciation: {
        'Polite': ['Apke acche words ke liye thanks. Kafi motivation mili.', 'Mai apke support aur feedback ke liye aabhari hu.'],
        'Friendly': ['Thanks a lot bhai! Tum toh sach me joss ho!', 'Much love bro! Tum hamesha sath dete ho!'],
        'Formal': ['Hum apke feedback ki appreciate karte hain aur aage bhi service dete rahenge.', 'Hum par trust karne ke liye dhanyawad.'],
        'Direct': ['Thanks. Apki help kafi kaam aayi.', 'Grateful.'],
        'Funny': ['Tarif karte raho bhai, maza aata hai!', 'Tarif sunkar dil garden-garden ho gaya boss! Treat kab hai?'],
        'Polite No': ['Appreciation ke liye thanks, but mai yeh offer accept nahi kar paunga.', 'Thanks for words, par mera decision change nahi hoga.'],
      },
      MessageIntent.general: {
        'Polite': ['Mai situation samajhta hu. Batane ke liye thanks.', 'Thik hai. Mai jald hi contact karunga.'],
        'Friendly': ['Samajh gaya bhai! Baad me baat karte hain.', 'Thik hai dost, chill! Baad me milta hu.'],
        'Formal': ['Apka message mil chuka hai. Hum updates jald hi share karenge.', 'Info share karne ke liye shukriya.'],
        'Direct': ['Samajh gaya. Next update jald milega.', 'Received. Action le raha hu.'],
        'Funny': ['Story toh thik hai, par chai kaun pila raha hai?', 'Haha, mast! Aage batao kya khabar hai?'],
        'Polite No': ['Message ke liye thanks, par is par meri koi opinion nahi hai.', 'Sorry, mai abhi is topic par kuch nahi keh sakta.'],
      },
    },
    'Bengali': {
      MessageIntent.greeting: {
        'Polite': ['অনেক দিন পর কথা হলো। কেমন চলছে সব?', 'আপনার বার্তাটি পেয়ে খুব ভালো লাগল।'],
        'Friendly': ['কী খবর রে? কী করিস?', 'আরে দোস্ত, খবর কী বল? অনেক দিন দেখা নাই!'],
        'Formal': ['আপনার বার্তাটি পেয়ে প্রীত হলাম। আশা করি সবকিছু ভালো চলছে।', 'শুভ অপরাহ্ন। আপনার দিনটি শুভ হোক।'],
        'Direct': ['বলুন, কী খবর?', 'জি বলুন, কীভাবে সাহায্য করতে পারি?'],
        'Funny': ['কেমন আছিস চাঁদের কণা?', 'কী খবর ওস্তাদ? আজ কার পেছনে লাগবি?'],
        'Polite No': ['আপনার মেসেজটি পেয়েছি। দুঃখিত যে এই মুহূর্তে ব্যস্ত আছি।', 'ধন্যবাদ। এখন কথা বলতে পারছি না।'],
      },
      MessageIntent.request: {
        'Polite': ['আমি অবশ্যই চেষ্টা করব বিষয়টি দেখার। একটু সময় দিন।', 'আপনার কাজটির ব্যাপারে সর্বোচ্চ চেষ্টা করব।'],
        'Friendly': ['আরে ব্যাপার না, আমি করে দিচ্ছি!', 'ঠিক আছে দোস্ত, আমি দেখছি কী করা যায়।'],
        'Formal': ['আপনার অনুরোধটি নথিভুক্ত করা হয়েছে। আমরা দ্রুত প্রয়োজনীয় পদক্ষেপ নিচ্ছি।', 'আমি যথাসম্ভব গুরুত্ব দিয়ে কাজটি সম্পন্ন করার চেষ্টা করছি।'],
        'Direct': ['কাজটি করব। একটু অপেক্ষা করুন।', 'হয়ে যাবে। সময় মতো পেয়ে যাবেন।'],
        'Funny': ['আমার মতো অলসকে দিয়ে এই কঠিন কাজ করাবি?', 'কাজ তো করব, কিন্তু বিরিয়ানি খাওয়াচ্ছিস কবে?'],
        'Polite No': ['দুঃখিত, এই মুহূর্তে এই অনুরোধটি রাখা আমার পক্ষে সম্ভব হচ্ছে না।', 'ব্যস্ততার কারণে কাজটি এখন করতে পারছি না। অত্যন্ত দুঃখিত।'],
      },
      MessageIntent.invitation: {
        'Polite': ['আমন্ত্রণের জন্য ধন্যবাদ। যাওয়ার সর্বাত্মক চেষ্টা থাকবে।', 'দাওয়াত পেয়ে আনন্দিত হলাম। অবশ্যই উপস্থিত থাকব।'],
        'Friendly': ['আরে যাব রে নিশ্চিত! পার্টি মিস করা যাবে না!', 'অবশ্যই আসব দোস্ত! ধামাকা হবে!'],
        'Formal': ['আপনার সদয় আমন্ত্রণের জন্য ধন্যবাদ। আমি যথাসময়ে উপস্থিত থাকতে সচেষ্ট হব।', 'এই সম্মানজনক অনুষ্ঠানে আমন্ত্রণ জানানোর জন্য কৃতজ্ঞতা প্রকাশ করছি।'],
        'Direct': ['ঠিক আছে, আসব। সময় মতো পৌঁছে যাব।', 'আমন্ত্রণ গ্রহণ করলাম। আমি আসছি।'],
        'Funny': ['খাওন-দাওন ভালো হলে আমি সবার আগে হাজির হব!', 'ফ্রি বিরিয়ানি থাকলে আমি কোনো দাওয়াত মিস করি না!'],
        'Polite No': ['আগে থেকে অন্য কাজ থাকায় এবার অংশ নিতে পারছি না। অত্যন্ত দুঃখিত।', 'আমার আন্তরিক শুভেচ্ছা রইল, তবে পারিবারিক কারণে এবার উপস্থিত হতে পারছি না।'],
      },
      MessageIntent.apology: {
        'Polite': ['ভুল বোঝাবুঝির জন্য আন্তরিকভাবে দুঃখিত। আশা করি ক্ষমা করবেন।', 'আমার অনাকাঙ্ক্ষিত ভুলের জন্য ক্ষমাপ্রার্থী।'],
        'Friendly': ['আরে রাগ করিস না দোস্ত, ভুল হয়ে গেছে!', 'সরি রে ভাই, ইচ্ছা করে করিনি। রাগ কমাস এবার!'],
        'Formal': ['যে অনাকাঙ্ক্ষিত পরিস্থিতি সৃষ্টি হয়েছে তার জন্য আমরা গভীরভাবে দুঃখ প্রকাশ করছি।', 'ভুলের দায় নিয়ে আমরা বিষয়টি দ্রুত সংশোধনের আশ্বাস দিচ্ছি।'],
        'Direct': ['ভুল হয়ে গেছে। আমি এটি ঠিক করে দিচ্ছি।', 'অসাবধানতার জন্য দুঃখিত। পুনরায় এমন হবে না।'],
        'Funny': ['কান ধরে ওঠবস করতে বলিস না প্লিজ! ভুল হয়ে গেছে!', 'আমি তো মানুষ, ভুল তো করতেই পারি! মাফ করে দে এবার!'],
        'Polite No': ['ভুলের জন্য দুঃখিত। তবে বিষয়টি নিয়ে আর কথা না বলাই শ্রেয় মনে করছি।', 'আমি দুঃখিত, তবে পরিস্থিতি বিবেচনায় এটাই আমার সিদ্ধান্ত।'],
      },
      MessageIntent.complaint: {
        'Polite': ['বিষয়টি অত্যন্ত দুঃখজনক। আমি এটি সমাধানের জন্য কথা বলছি।', 'আপনার সমস্যার জন্য আমরা ব্যথিত। দ্রুত ব্যবস্থা নেওয়া হচ্ছে।'],
        'Friendly': ['ধুর ভাই, মেজাজটাই খারাপ হয়ে গেল! আমি দেখছি কী করা যায়।', 'খারাপ লাগারই কথা রে ভাই, দাঁড়াও একটু খোঁজ নেই।'],
        'Formal': ['আমরা বিষয়টি অত্যন্ত গুরুত্ব সহকারে তদন্ত করছি এবং দ্রুত প্রতিকার নিশ্চিত করব।', 'আপনার অভিযোগের ভিত্তিতে দায়িত্বপ্রাপ্ত কর্মকর্তাকে বিষয়টি অবহিত করা হয়েছে।'],
        'Direct': ['এটি মেনে নেওয়া যায় না। আমি অবিলম্বে এটি বাতিল/ঠিক করতে বলছি।', 'অভিযোগটি আমলে নেওয়া হয়েছে। দ্রুত অ্যাকশন নেওয়া হবে।'],
        'Funny': ['মনে হচ্ছে আমাদের ভাগ্যটাই খারাপ! তবে রেগে গিয়ে লাভ নেই!', 'এদের তো ঝাড়ু দিয়ে পিটানো উচিত! দাঁড়াও ব্যবস্থা করছি!'],
        'Polite No': ['আমরা আপনার মতামত গ্রহণ করেছি, তবে নীতিমালার বাইরে যাওয়া আমাদের পক্ষে সম্ভব নয়।', 'অভিযোগটির জন্য ধন্যবাদ, তবে এই মুহূর্তে আর কোনো ক্ষতিপূরণ দেওয়া সম্ভব নয়।'],
      },
      MessageIntent.paymentReminder: {
        'Polite': ['একটু মনে করিয়ে দিচ্ছিলাম, বকেয়া পেমেন্টটি পরিশোধ করলে ভালো হতো।', 'যদি সম্ভব হয় পেমেন্টটি দ্রুত সম্পন্ন করার অনুরোধ রইল।'],
        'Friendly': ['দোস্ত, অনেক দিন হলো, টাকাটা একটু বিকাশ করে দে না!', 'টাকার বড্ড দরকার রে ভাই, পেমেন্টটা একটু ক্লিয়ার কর দ্রুত!'],
        'Formal': ['আপনার পূর্বের ইনভয়েসের বিপরীতে বকেয়া অর্থ পরিশোধের জন্য বিনীত অনুরোধ জানাচ্ছি।', 'অনুগ্রহ করে চুক্তি অনুযায়ী আপনার বকেয়া বিলটি পরিশোধের ব্যবস্থা করুন।'],
        'Direct': ['বকেয়া বিলটি দ্রুত পরিশোধ করুন। অ্যাকাউন্ট নম্বর উপরে দেওয়া আছে।', 'আজকের মধ্যে পেমেন্টটি ক্লিয়ার করা আবশ্যক।'],
        'Funny': ['টাকা তো দিতেই হবে ওস্তাদ, পকেট খালি করে হলেও দিয়ে দিন!', 'টাকা দিলে জান বাঁচে, বিলটা একটু শোধ করে দাও না ভাই!'],
        'Polite No': ['দুঃখিত, বকেয়া পরিশোধ না করা পর্যন্ত আমরা নতুন কাজ শুরু করতে পারছি না।', 'নিয়ম অনুযায়ী পেমেন্ট ছাড়া আর সময় দেওয়া সম্ভব হচ্ছে না।'],
      },
      MessageIntent.work: {
        'Polite': ['আমি ইতিমধ্যে কাজের রিপোর্টটি তৈরি করতে শুরু করেছি। দ্রুত পাবেন।', 'মিটিংয়ের এজেন্ডা প্রস্তুত রয়েছে। আমরা সময় মতো শুরু করব।'],
        'Friendly': ['কাজটা করছি দোস্ত, আর একটু লাগবে। টেনশন নিস না!', 'বসকে দেওয়ার আগে একবার চেক করে নেব ভাই।'],
        'Formal': ['নির্ধারিত ডেডলাইনের মধ্যে প্রজেক্টের ডেলিভারি নিশ্চিত করার সর্বাত্মক চেষ্টা করা হচ্ছে।', 'আজকের মিটিংয়ের কার্যবিবরণী ইমেইলে পাঠিয়ে দেওয়া হবে।'],
        'Direct': ['কাজ চলছে। ডেডলাইনের মধ্যে সম্পন্ন হবে।', 'রিপোর্ট তৈরি। ইমেইল চেক করুন।'],
        'Funny': ['খাটতে খাটতে জীবন শেষ! তবুই তো বসের মন ভরে না!', 'কাজ তো করতে হবে ওস্তাদ, কিন্তু বেতনটা একটু বাড়লে ভালো হতো!'],
        'Polite No': ['দুঃখিত, আমার কাজের পরিধি ও সময়ের স্বল্পতার কারণে এই নতুন দায়িত্বটি নিতে পারছি না।', 'আজ অতিরিক্ত কাজের চাপের কারণে মিটিংয়ে যোগ দেওয়া সম্ভব হচ্ছে না।'],
      },
      MessageIntent.customerQuery: {
        'Polite': ['আমাদের প্রোডাক্টের মূল্য এবং বিস্তারিত বিবরণ মেসেজে পাঠানো হলো।', 'পণ্যটি এখনো স্টকে আছে। আপনি অর্ডার করতে পারেন।'],
        'Friendly': ['দাম একদম কম ভাইয়া! অর্ডার করতে ইনবক্স করো এখনই!', 'সাইজ আর কালার অনেকগুলো আছে দোস্ত, কোনটা লাগবে বল?'],
        'Formal': ['আমাদের পণ্যের মূল্য তালিকা ও ডেলিভারি চার্জের বিবরণী সংযুক্ত করা হলো।', 'আমাদের সাথে যোগাযোগ করার জন্য ধন্যবাদ। পণ্যটি ৩-৫ কার্যদিবসের মধ্যে ডেলিভারি করা হবে।'],
        'Direct': ['মূল্য ১,২০০ টাকা। ক্যাশ অন ডেলিভারি প্রযোজ্য।', 'স্টক সীমিত। অর্ডার করতে নাম ও ফোন নম্বর দিন।'],
        'Funny': ['দাম শুনে চোখ কপালে তোলার কিছু নেই, কোয়ালিটি অনেক ভালো!', 'আরে ওস্তাদ, সেরা জিনিস একদম সস্তায় দিচ্ছি! নিয়ে যান!'],
        'Polite No': ['দুঃখিত, এই পণ্যটি আর স্টকে নেই এবং পুনরায় আসার সম্ভাবনা কম।', 'এই মুহূর্তে পণ্যের মূল্যে কোনো ছাড় দেওয়া সম্ভব হচ্ছে না।'],
      },
      MessageIntent.boundary: {
        'Polite': ['অনুগ্রহ করে অফিস সময়ের বাইরে যোগাযোগ না করার অনুরোধ রইল।', 'ব্যক্তিগত বিষয়ে কথা না বলাই আমার জন্য সুবিধাজনক।'],
        'Friendly': ['ভাই, এগুলা ফালতু কথা বাদ দে তো! নিজের চরকায় তেল দে।', 'আমার লাইফ নিয়ে তোকে ভাবতে হবে না রে ভাই, চিল কর!'],
        'Formal': ['পেশাগত সীমানা বজায় রাখার স্বার্থে অনুগ্রহ করে অফিশিয়াল মাধ্যম ব্যবহার করুন।', 'আপনার এই ধরনের মন্তব্য অনাকাঙ্ক্ষিত এবং শিষ্টাচার বহির্ভূত।'],
        'Direct': ['আমাকে আর মেসেজ বা কল করবেন না।', 'এই বিষয়ে আলোচনা এখানেই শেষ করতে চাই।'],
        'Funny': ['আমার এত খোঁজ নিয়ে কী করবি? গোয়েন্দা বিভাগে চাকরি নিবি?', 'সীমানা পার হলে কিন্তু লাল কার্ড দেখতে হতে পারে ওস্তাদ!'],
        'Polite No': ['ধন্যবাদ, তবে আপনার সাথে এ বিষয়ে আর কোনো আলোচনা বাড়াতে ইচ্ছুক নই।', 'আমি আপনাকে ব্লক করতে বাধ্য হব যদি পুনরায় এমন মেসেজ পাঠান।'],
      },
      MessageIntent.appreciation: {
        'Polite': ['আপনার চমৎকার মন্তব্যের জন্য ধন্যবাদ। কাজের অনুপ্রেরণা পেলাম।', 'কৃতজ্ঞতা জানাই। আপনার সহযোগিতা সত্যিই প্রশংসনীয়।'],
        'Friendly': ['আরে থ্যাংকস দোস্ত! তুই সবসময় পাশে থাকিস!', 'অনেক ভালোবাসা রে ভাই! তুই জোস!'],
        'Formal': ['আপনার মূল্যবান মতামত ও সমর্থনের জন্য আমরা অত্যন্ত আনন্দিত ও কৃতজ্ঞ।', 'আমাদের সেবায় সন্তুষ্ট হওয়ার জন্য ধন্যবাদ। ভবিষ্যতেও পাশে থাকবেন আশা করি।'],
        'Direct': ['ধন্যবাদ। আপনার সহযোগিতা কাজে লেগেছে।', 'কৃতজ্ঞতা প্রকাশ করছি।'],
        'Funny': ['এত প্রশংসা করিস না দোস্ত, সর্দি লেগে যাবে তো!', 'প্রশংসা শুনে বুকটা ভরে গেল ওস্তাদ! বিরিয়ানি খাওয়া এবার!'],
        'Polite No': ['ধন্যবাদ আপনার সুন্দর কথার জন্য, তবে আমি এই অফারটি গ্রহণ করতে পারছি না।', 'প্রশংসার জন্য কৃতজ্ঞ, তবে আমার সিদ্ধান্ত অপরিবর্তিত থাকছে।'],
      },
      MessageIntent.general: {
        'Polite': ['আমি বিষয়টি বুঝতে পেরেছি। ধন্যবাদ জানানোর জন্য।', 'ঠিক আছে। আমি শীঘ্রই আপনার সাথে আবার যোগাযোগ করছি।'],
        'Friendly': ['বুঝেছি দোস্ত। পরে কথা হবে তাহলে।', 'ওকে ভাই, চিল! পরে কথা বলি।'],
        'Formal': ['আপনার বার্তাটি সফলভাবে গৃহীত হয়েছে। যথাসময়ে আমরা ফিডব্যাক জানাব।', 'তথ্যটি শেয়ার করার জন্য আপনাকে আন্তরিক ধন্যবাদ জ্ঞাপন করছি।'],
        'Direct': ['ঠিক আছে। পরবর্তী আপডেট দ্রুত জানানো হবে।', 'বুঝেছি। অ্যাকশন নিচ্ছি।'],
        'Funny': ['কাহিনী তো সব বুঝলাম, কিন্তু চা খাওয়াবে কে?', 'হাহা, চমৎকার! তারপর বলো আর কী খবর?'],
        'Polite No': ['বার্তাটির জন্য ধন্যবাদ, তবে এ ব্যাপারে আমার কোনো মতামত নেই।', 'দুঃখিত, আমি এই বিষয়ে এখন কোনো মন্তব্য করতে চাচ্ছি না।'],
      },
    },
    'Banglish': {
      MessageIntent.greeting: {
        'Polite': ['Onek din por kotha holo. Kemon cholche shob?', 'Apnar message peye bhalo laglo.'],
        'Friendly': ['Ki khobor dost? Ki korish?', 'Areh bhai, khobor ki bol? Onekdin dekha nai!'],
        'Formal': ['Apnar message peye khushi holam. Asha kori shob bhalo ache.', 'Good afternoon. Hope you are having a great day.'],
        'Direct': ['Bolun, ki khobor?', 'Ji bolun, kivabe help korte pari?'],
        'Funny': ['Kemon achis chader kona?', 'Ki khobor ostad? Aaj kar pichone lagbi?'],
        'Polite No': ['Apnar message peyechi. Ektu busy achi ekhon.', 'Thanks. Ekhon kotha bolte parchi na.'],
      },
      MessageIntent.request: {
        'Polite': ['Ami try korbo oboshoy. Ektu somoy din please.', 'Apnar kajtar jonno ami best try korbo.'],
        'Friendly': ['Areh chill, ami kore dicchi!', 'Thik ache dost, ami dekhchi ki kora jay.'],
        'Formal': ['Apnar request ti neya hoyeche. Amra khub druto kaj korbo.', 'Ami jotoshombhob gurutbo diye kajti korar cheshta korbo.'],
        'Direct': ['Kajti korbo. Ektu wait koren.', 'Hoye jabe. Time moto peye jaben.'],
        'Funny': ['Amar moto alosh ke diye ei kaj korabi?', 'Kaj toh korbo, kintu biryani khawacchis kobe?'],
        'Polite No': ['Sorry, ei muhurte ei request rakha shombhob na.', 'Busy thakar karone kajta korte parchi na. Extremely sorry.'],
      },
      MessageIntent.invitation: {
        'Polite': ['Invite korar jonno thanks. Jawar best try thakbe.', 'Dawat peye bhalo laglo. Oboshoy thakbo.'],
        'Friendly': ['Areh jabo re confirm! Party miss kora jabe na!', 'Oboshoy ashbo dost! Dhamaka hobe!'],
        'Formal': ['Sodoy amontroner jonno dhonnobad. Ami jotoshomoye thakte cheshta korbo.', 'Ei shommanjonok onusthane invite koray kritoggota.'],
        'Direct': ['Thik ache, ashbo. Time moto pouche jabo.', 'Dawat accept korlam. Ashchi ami.'],
        'Funny': ['Khawa-dawa bhalo hole ami shobar age hazir!', 'Free biryani thakle kono dawat miss kori na!'],
        'Polite No': ['Ager kaj thakar karone ebar join korte parchi na. Extremely sorry.', 'Shubhokamona roilo, kintu ebar thakte parchi na personal busy thakay.'],
      },
      MessageIntent.apology: {
        'Polite': ['Bhul bujhabujhir jonno sorry. Asha kori khoma korben.', 'Amar anankankhito bhuler jonno sorry.'],
        'Friendly': ['Areh rag korish na dost, bhul hoye geche!', 'Sorry re bhai, iccha kore korini. Rag koma ebar!'],
        'Formal': ['Je situation hoyeche tar jonno amra shantoptop. Druto correction korchi.', 'Bhuler day niye amra kajti druto thik korar assurance dicchi.'],
        'Direct': ['Bhul hoye geche. Ami thik kore dicchi.', 'Sorry, next time emon hobe na.'],
        'Funny': ['Kan dhore uthbosh korte bolish na plz! Vul hoye geche!', 'Ami toh manush, vul toh hotei pare! Maf kor ebar!'],
        'Polite No': ['Bhuler jonno sorry. But eta niye r kotha na bolai bhalo.', 'Ami sorry, but eta amar final decision.'],
      },
      MessageIntent.complaint: {
        'Polite': ['Eta khuboi kharap holo. Ami solve korar jonno kotha bolchi.', 'Apnar problem er jonno amra sorry. Druto action nicchi.'],
        'Friendly': ['Dhur bhai, matha tai kharap hoye gelo! Dekhchi ki kora jay.', 'Kharap lagar i kotha re bhai, darao dekhchi.'],
        'Formal': ['Amra shomosshati gurutbo shoho dekhchi ebong fast solve korbo.', 'Apnar complaint basis e officer ke janano hoyeche.'],
        'Direct': ['Eta accept kora jay na. Ami ekhoni cancel/thik korte bolchi.', 'Complaint peyechi. Fast action hobe.'],
        'Funny': ['Luck tai kharap bodhoy! But rag kore labh nai!', 'Eder toh pitano dorkar! Darao ektukhani!'],
        'Polite No': ['Amra feedback niyechi, kintu rules er baire jawa shombhob na.', 'Thanks for info, but are kono compensation deya shombhob na.'],
      },
      MessageIntent.paymentReminder: {
        'Polite': ['Ektu mone koriye dicchilam, payment ta clear korle bhalo hoto.', 'Shombhob hole payment ta fast complete korar request roilo.'],
        'Friendly': ['Dost, onek din holo, taka ta ektu bkash kore de na!', 'Takar khub dorkar re bhai, payment ta fast clear kor!'],
        'Formal': ['Apnar previous invoice er payment ti clear korar jonno request korchi.', 'Kindly agreement anujayi bokeya bill ta pay koren.'],
        'Direct': ['Bill ta fast pay koren. Account details upore deya ache.', 'Ajker moddhe payment clear kora lagbe.'],
        'Funny': ['Taka toh deya e lagbe ostad, pocket khali kore holeo diye den!', 'Taka dile jaan bache, bill ta shodh kore dao na bhai!'],
        'Polite No': ['Sorry, payment complete na hole new work start korte parchi na.', 'Rules anujayi payment chada extension deya shombhob na.'],
      },
      MessageIntent.work: {
        'Polite': ['Ami already report ta ready kortechi. Fast peye jaben.', 'Meeting agenda ready. Time moto start korbo.'],
        'Friendly': ['Kaj ta kortesi dost, r ektu lagbe. Chill!', 'Boss ke dewar age ebar check kore nebo re bhai.'],
        'Formal': ['Deadline er moddhe project delivery er best try cholche.', 'Ajker meeting minutes mail e pathiye deya hobe.'],
        'Direct': ['Kaj cholche. Deadline e ready hobe.', 'Report ready. Mail check koren.'],
        'Funny': ['Khatte khatte sesh! Tobuo boss er mon bhore na!', 'Kaj toh korboi ostad, but salary ta barle bhalo hoto!'],
        'Polite No': ['Sorry, workload er jonno new kaj nite parchi na.', 'Ajj overload thakar jonno meeting e thaka shombhob na.'],
      },
      MessageIntent.customerQuery: {
        'Polite': ['Amader product er price ebong details inbox kora holo.', 'Product ekhono stock e ache. Order korte paren.'],
        'Friendly': ['Dam ekdom kom bhaia! Order korte ekhoni inbox koro!', 'Size r color onek ache dost, konta lagbe bol?'],
        'Formal': ['Amader products rate ebong delivery charges details share kora holo.', 'Amader sathe jogajog er jonno thanks. 3-5 days e delivery hobe.'],
        'Direct': ['Price 1,200 taka. Cash on delivery pathan.', 'Stock limited. Order er jonno name & phone number den.'],
        'Funny': ['Dam shune chokh kopale tulben na, quality best!', 'Areh ostad, best jinis kom dame dicchi! Niye jan!'],
        'Polite No': ['Sorry, eta stock out hoye geche and next e ashar chance kom.', 'Ei muhurte rate e discount deya possible na.'],
      },
      MessageIntent.boundary: {
        'Polite': ['Kindly office hour er baire call/message na korar request roilo.', 'Personal matter e kotha na bolai bhalo hoto.'],
        'Friendly': ['Bhai, faltu kotha bad de toh! Nije chorkay tel de.', 'Amar life niye tui chil kor, matha ghamate hobe na.'],
        'Formal': ['Professional boundary maintain er jonno official channel use korun.', 'Apnar emon comment unexpected ebong rules er baire.'],
        'Direct': ['Amake r text ba call korben na.', 'Ei topic e discuss ekhanei sesh.'],
        'Funny': ['Amar khobor niye ki korbi? Detective hobi?', 'Boundary cross korle red card pabi kintu ostad!'],
        'Polite No': ['Thanks, but eishob niye r discuss korte cachi na.', 'Emon message dile block korte baddho hobo.'],
      },
      MessageIntent.appreciation: {
        'Polite': ['Chomokkar comment er jonno thanks. Work inspiration pelam.', 'Kritoggota janai. Apnar support awesome.'],
        'Friendly': ['Areh thanks dost! Tui shob shomoy thakish!', 'Onek bhalobasha re bhai! Tui joss!'],
        'Formal': ['Apnar feedback er jonno amra happy & grateful.', 'Amader service e happy thakar jonno thanks.'],
        'Direct': ['Dhonnobad. Apnar support lagbe.', 'Kritoggota.'],
        'Funny': ['Eto prosongsha korish na dost, matha ghure jabe!', 'Shune bukta bhore gelo ostad! Biryani khawa ebar!'],
        'Polite No': ['Thanks for nice words, but offer accept korte parchi na.', 'Appreciation er jonno thanks, but amar decision same.'],
      },
      MessageIntent.general: {
        'Polite': ['Ami shomossha ta bujhte perechi. Dhonnobad.', 'Thik ache. Ami shiggori contact korchi.'],
        'Friendly': ['Bujhechi dost. Pore kotha hobe.', 'Ok bhai, chill! Pore kotha boli.'],
        'Formal': ['Apnar message received. Jotoshomoye feedback jano hobe.', 'Info share er jonno dhonnobad.'],
        'Direct': ['Thik ache. Next update fast paben.', 'Bujhechi. Action nicchi.'],
        'Funny': ['Kahini toh shob bujlam, tea khaway ke?', 'Haha, nice! Porer khobor bolo.'],
        'Polite No': ['Thanks for text, but eta niye amar kono opinion nai.', 'Sorry, ami ekhon eta niye comment korchi na.'],
      },
    },
    'Tamil': {
      MessageIntent.greeting: {
        'Polite': ['ரொம்ப நாள் ஆச்சு. எப்படி போயிட்டு இருக்கு?', 'உங்கள் செய்திக்கு மிக்க மகிழ்ச்சி.'],
        'Friendly': ['ஹேய்! எப்படி இருக்கே?', 'நண்பா! ரொம்ப நாள் ஆச்சு, எப்படி இருக்கிறாய்?'],
        'Formal': ['உங்களுடன் தொடர்புகொள்வதில் மகிழ்ச்சி. எல்லாம் நலமா?', 'வணக்கம். நீங்கள் நலமாக இருக்கிறீர்கள் என்று நம்புகிறேன்.'],
        'Direct': ['சொல்லுங்கள், நான் என்ன உதவி செய்ய வேண்டும்?', 'வணக்கம், உங்கள் கேள்வி என்னவென்று சொல்லுங்கள்.'],
        'Funny': ['என்ன சூப்பர் ஸ்டார்! என்ன விசேஷம்?', 'யாரென்று பாருங்கள்! என்ன உதவி வேண்டும்?'],
        'Polite No': ['உங்கள் செய்தி கிடைத்தது. இப்போது நான் கொஞ்சம் வேலையாக இருக்கிறேன்.', 'நன்றி. இப்போது பேச முடியாது.'],
      },
      MessageIntent.request: {
        'Polite': ['நான் நிச்சயமாக இதற்கு முயற்சி செய்கிறேன். கொஞ்சம் நேரம் கொடுங்கள்.', 'உங்கள் கோரிக்கையை நிறைவேற்ற முழு முயற்சி செய்கிறேன்.'],
        'Friendly': ['கண்டிப்பா நண்பா, நான் பண்ணித் தர்றேன்!', 'ஒன்னும் பிரச்சனை இல்ல, நான் என்ன பண்ண முடியும்னு பார்க்கிறேன்.'],
        'Formal': ['உங்கள் கோரிக்கை பதிவு செய்யப்பட்டுள்ளது. விரைவில் நடவடிக்கை எடுக்கப்படும்.', 'முன்னுரிமை அடிப்படையில் நான் உங்கள் கோரிக்கையை பரிசீலிக்கிறேன்.'],
        'Direct': ['நான் இதைச் செய்கிறேன். காத்திருங்கள்.', 'சரி, சொன்ன நேரத்தில் வேலை முடிந்துவிடும்.'],
        'Funny': ['என்னை மாதிரி ஒரு சோம்பேறிக்கிட்ட வேலை வாங்குறீங்களா? சரி பண்ணுவோம்!', 'வேலை நடக்கும், ஆனால் எனக்கு பிரியாணி எப்போ தர்றீங்க?'],
        'Polite No': ['வருந்துகிறேன், இப்போது என்னால் இந்த உதவி செய்ய முடியாது.', 'மற்ற வேலைகள் இருப்பதால், இக்கோரிக்கையை ஏற்க இயலவில்லை.'],
      },
      MessageIntent.invitation: {
        'Polite': ['அழைப்பிற்கு நன்றி. நான் வர முயற்சி செய்கிறேன்.', 'அழைப்பிற்கு நன்றி. கண்டிப்பாக வருகிறேன்.'],
        'Friendly': ['கண்டிப்பா வர்றேன் நண்பா! பார்ட்டிய மிஸ் பண்ண முடியுமா!', 'என்னையும் சேர்த்துக்கோங்க! செமயா கொண்டாடலாம்!'],
        'Formal': ['அன்பான அழைப்பிற்கு நன்றி. என் நேரத்திற்கு ஏற்ப கலந்து கொள்ள முயல்கிறேன்.', 'நிகழ்ச்சிக்கு அழைத்தமைக்கு எனது நன்றிகள்.'],
        'Direct': ['சரி, நான் வருகிறேன்.', 'அழைப்பை ஏற்றுக்கொண்டேன். சந்திப்போம்.'],
        'Funny': ['இலவச சாப்பாடு இருந்தால் கேட்கவே தேவையில்லை, நான் ரெடி!', 'பார்ட்டிய கலக்க நான் வர்றேன், கவலைப்படாதீங்க!'],
        'Polite No': ['முன்னரே திட்டமிட்ட வேலை இருப்பதால் என்னால் வர இயலவில்லை.', 'வருந்துகிறேன், தவிர்க்க முடியாத காரணங்களால் என்னால் வர முடியாது.'],
      },
      MessageIntent.apology: {
        'Polite': ['புரிந்துகொள்ளாமைக்கு எனது மன்னிப்பை கேட்டுக்கொள்கிறேன்.', 'ஏற்பட்ட சிரமத்திற்கு தயவுசெய்து எனது மன்னிப்பை ஏற்றுக்கொள்ளுங்கள்.'],
        'Friendly': ['சாரி நண்பா, தப்பு நடந்துடுச்சு!', 'தெரியாம நடந்துடுச்சு மச்சான்! கோபத்த விடு இப்ப!'],
        'Formal': ['இந்த தவறுக்கு நாங்கள் வருந்துகிறோம் மற்றும் சரிசெய்ய நடவடிக்கை எடுத்து வருகிறோம்.', 'எங்கள் சேவையில் ஏற்பட்ட இந்த தவறுக்கு மன்னிப்பு கேட்டுக்கொள்கிறோம்.'],
        'Direct': ['என் தவறுதான். நான் இதை உடனே சரி செய்கிறேன்.', 'மன்னிக்கவும். மீண்டும் இப்படி நடக்காது.'],
        'Funny': ['தோப்புக்கரணம் போடச் சொல்லாதீங்க ப்ளீஸ்! மன்னிச்சிடுங்க!', 'நானும் மனுஷன் தானே, தப்பு நடப்பது சகஜம் தானே! கோபப்படாதீங்க!'],
        'Polite No': ['மன்னிக்கவும், ஆனால் இந்த விஷயத்தில் இதுவே எனது இறுதி முடிவு.', 'வருந்துகிறேன், ஆனால் சூழ்நிலையைக் கருத்தில் கொண்டு என் முடிவு சரியானது.'],
      },
      MessageIntent.complaint: {
        'Polite': ['இது வருத்தத்திற்குரியது. நான் இதை சரி செய்ய ஏற்பாடு செய்கிறேன்.', 'உங்களுக்கு ஏற்பட்ட சிரமத்திற்கு வருந்துகிறோம். உடனே சரி செய்கிறோம்.'],
        'Friendly': ['ரொம்ப கடுப்பா இருக்கு மச்சான்! நான் என்ன பண்ண முடியும்னு பார்க்கிறேன்.', 'வருத்தமாக இருக்கிறது நண்பா, இது சரியில்லை. நான் செக் செய்கிறேன்.'],
        'Formal': ['நாங்கள் இந்த விஷயத்தை உடனடியாக விசாரிக்கிறோம்.', 'உங்கள் புகார் உயர் நிர்வாகத்திற்கு அனுப்பப்பட்டுள்ளது.'],
        'Direct': ['இது ஏற்றுக்கொள்ள முடியாதது. உடனடியாக சரி செய்ய உத்தரவிடுகிறேன்.', 'புகார் பெறப்பட்டது. உடனடியாக நடவடிக்கை எடுக்கப்படும்.'],
        'Funny': ['விஷயம் கைமீறி போய்விட்டது! சரி, இதை சரி செய்வோம்.', 'யார் இதை சொதப்பியது என்று நான் கண்டுபிடிக்கிறேன்.'],
        'Polite No': ['உங்கள் அதிருப்தியை நாங்கள் மதிக்கிறோம், ஆனால் நாங்கள் விதிமுறைகளைப் பின்பற்ற வேண்டும்.', 'புகாருக்கு நன்றி, ஆனால் இதில் மேலும் மாற்றம் செய்ய இயலாது.'],
      },
      MessageIntent.paymentReminder: {
        'Polite': ['நிலுவையில் உள்ள தொகையை செலுத்துவதற்கான நினைவூட்டல்.', 'தயவுசெய்து கட்டணத்தின் நிலையை சரிபார்க்க முடியுமா?'],
        'Friendly': ['நண்பா, கொஞ்சம் பேமெண்ட் இன்னைக்கு அனுப்பிடுறியா!', 'டைம்க்கு பில் கிளியர் பண்ணா நல்லா இருக்கும் மச்சான்!'],
        'Formal': ['தயவுசெய்து சேவைகளுக்கான நிலுவைத் தொகையை விரைவில் செலுத்துமாறு கேட்டுக்கொள்கிறோம்.', 'இது கட்டணத்திற்கான ஒரு முறைப்படியான நினைவூட்டல்.'],
        'Direct': ['தயவுசெய்து நிலுவைத் தொகையை செலுத்துங்கள். விவரங்கள் மேலே உள்ளன.', 'இன்றே பணம் செலுத்த வேண்டும். தயவுசெய்து கிளியர் செய்யவும்.'],
        'Funny': ['பணம் தான் முக்கியம் பாஸ்! சீக்கிரம் அனுப்பிடுங்க!', 'வேலை பிடிக்கும், ஆனால் பணம் இன்னும் ரொம்ப பிடிக்கும்! கிளியர் பண்ணுங்க!'],
        'Polite No': ['வருந்துகிறேன், பணம் செலுத்தும் வரை எங்களால் அடுத்த வேலையை செய்ய முடியாது.', 'விதிமுறைகளின்படி, இந்த கட்டணத்தில் எந்த சலுகையும் வழங்க முடியாது.'],
      },
      MessageIntent.work: {
        'Polite': ['நான் அறிக்கையை தயார் செய்து கொண்டிருக்கிறேன், விரைவில் அனுப்புகிறேன்.', 'கூட்டத்திற்கான நிகழ்ச்சி நிரல் தயார். சரியான நேரத்திற்கு தொடங்குவோம்.'],
        'Friendly': ['வேலையில் இருக்கேன் நண்பா! சீக்கிரம் அனுப்பிடுறேன், சில் பண்ணு!', 'பாஸ் பார்க்குறதுக்கு முன்னாடி நான் ஒருவாட்டி செக் பண்ணிடுறேன்.'],
        'Formal': ['திட்டத்தின் காலக்கெடுவை எட்ட முழு முயற்சி எடுக்கப்பட்டு வருகிறது.', 'இன்றைய கூட்டத்தின் விவரங்கள் மின்னஞ்சல் மூலம் அனுப்பப்படும்.'],
        'Direct': ['வேலை நடந்து கொண்டிருக்கிறது. காலக்கெடுவிற்குள் முடிந்துவிடும்.', 'அறிக்கை தயார். உங்கள் மின்னஞ்சலை சரிபார்க்கவும்.'],
        'Funny': ['வேலை செய்யத்தான் வேண்டியிருக்கு, வேற என்ன பண்றது!', 'கோடிங் பண்ண பிரியாணி கிடைச்சா எவ்வளவு நல்லா இருக்கும்! வேலை நடக்குது!'],
        'Polite No': ['வேலைப்பளு காரணமாக என்னால் இந்த புதிய பொறுப்பை ஏற்க முடியாது.', 'அவசர வேலை இருப்பதால் இன்றைய கூட்டத்தில் கலந்து கொள்ள முடியாது.'],
      },
      MessageIntent.customerQuery: {
        'Polite': ['விலை மற்றும் விவரங்கள் உங்கள் இன்பாக்ஸிற்கு அனுப்பப்பட்டுள்ளன.', 'இந்த பொருள் இப்போது கைவசம் உள்ளது மற்றும் அனுப்ப தயாராக உள்ளது.'],
        'Friendly': ['விலை ரொம்ப கம்மி அண்ணா! ஆர்டர் செய்ய இன்பாக்ஸ் பண்ணுங்க!', 'எங்களிடம் நிறைய நிறங்கள் மற்றும் அளவுகள் உள்ளன. உங்களுக்கு எது வேண்டும்?'],
        'Formal': ['தயவுசெய்து இணைக்கப்பட்டுள்ள விலை பட்டியல் மற்றும் விநியோக நிபந்தனைகளைப் பார்க்கவும்.', 'கேள்விக்கு நன்றி. பொருள் 3 நாட்களுக்குள் அனுப்பப்படும்.'],
        'Direct': ['விலை 1,200 ரூபாய். கேஷ் ஆன் டெலிவரி உள்ளது.', 'ஸ்டாக் குறைவாக உள்ளது. ஆர்டர் செய்ய பெயர் மற்றும் எண்ணை அனுப்பவும்.'],
        'Funny': ['விலையை கேட்டு அதிர்ச்சியாக வேண்டாம், தரம் மிகவும் அருமை!', 'மிகவும் மலிவானது மற்றும் சிறந்தது! இன்றே வாங்கிடுங்க பாஸ்!'],
        'Polite No': ['வருந்துகிறோம், இந்த பொருள் இப்போது தீர்ந்துவிட்டது மற்றும் மீண்டும் வராது.', 'வருந்துகிறோம், தற்போது எந்த தள்ளுபடியும் வழங்க முடியாது.'],
      },
      MessageIntent.boundary: {
        'Polite': ['தயவுசெய்து வேலை நேரத்திற்குப் பிறகு என்னை தொடர்பு கொள்ள வேண்டாம்.', 'நமது உரையாடல்களை தொழில்முறையாக மட்டுமே வைத்திருக்க விரும்புகிறேன்.'],
        'Friendly': ['நண்பா, வேலை விஷயத்தை மட்டும் பேசுவோம், தேவையில்லாத பேச்சு வேண்டாம்.', 'என் தனிப்பட்ட விஷயங்களை பகிர்ந்து கொள்ள விரும்பவில்லை, நன்றி.'],
        'Formal': ['எதிர்கால தொடர்புகளுக்கு தயவுசெய்து அதிகாரப்பூர்வ வழிகளைப் பயன்படுத்தவும்.', 'இந்த கேள்வி நமது ஒப்பந்த வரம்பிற்கு அப்பாற்பட்டது.'],
        'Direct': ['தயவுசெய்து எனக்கு மீண்டும் போன் செய்யவோ மெசேஜ் அனுப்பவோ வேண்டாம்.', 'இத்துடன் இந்த உரையாடலை முடிக்க விரும்புகிறேன்.'],
      },
      MessageIntent.appreciation: {
        'Polite': ['உங்கள் அன்பான வார்த்தைகளுக்கு நன்றி. மிகவும் பாராட்டத்தக்கது.', 'உங்கள் ஆதரவிற்கும் கருத்துக்களுக்கும் நான் நன்றியுள்ளவனாக இருக்கிறேன்.'],
        'Friendly': ['மிக்க நன்றி நண்பா! நீங்க தான் கெத்து!', 'அன்பான நன்றிகள் மச்சான்! எப்போதும் கூட நிற்பதற்கு நன்றி!'],
        'Formal': ['உங்கள் கருத்தை நாங்கள் மதிக்கிறோம் மற்றும் உங்களுக்கு சேவை செய்ய காத்திருக்கிறோம்.', 'எங்கள் மீது நம்பிக்கை வைத்ததற்கு நன்றி.'],
        'Direct': ['நன்றி. உங்கள் உதவி மிகவும் பயனுள்ளதாக இருந்தது.', 'நன்றிகள்.'],
        'Funny': ['புகழ்ந்துகொண்டே இருங்கள் நண்பா, எனக்கு மிகவும் பிடிக்கும்!', 'புகழ்ச்சியை கேட்டு நெஞ்சம் குளிர்ந்துவிட்டது பாஸ்! எப்போ ட்ரீட்?'],
        'Polite No': ['பாராட்டுக்கு நன்றி, ஆனால் என்னால் இந்த சலுகையை ஏற்க முடியாது.', 'பாராட்டுக்கு நன்றி, ஆனால் என் முடிவில் மாற்றம் இல்லை.'],
      },
      MessageIntent.general: {
        'Polite': ['நான் சூழ்நிலையை புரிந்துகொள்கிறேன். தகவலுக்கு நன்றி.', 'சரி. நான் விரைவில் உங்களை மீண்டும் தொடர்பு கொள்கிறேன்.'],
        'Friendly': ['புரிந்தது நண்பா! அப்புறம் பேசுவோம்.', 'சரி மச்சான், சில்! அப்புறம் பார்க்குறேன்.'],
        'Formal': ['உங்கள் செய்தி பெறப்பட்டது. விவரங்களை விரைவில் உங்களுக்கு தெரிவிப்போம்.', 'தகவலைப் பகிர்ந்ததற்கு நன்றி.'],
        'Direct': ['புரிந்தது. அடுத்த அப்டேட் விரைவில் வரும்.', 'பெறப்பட்டது. நடவடிக்கை எடுக்கிறேன்.'],
        'Funny': ['கதை புரிந்தது, ஆனால் காபி யார் வாங்கித் தருவது?', 'ஹஹஹ, அருமை! அப்புறம் என்ன விசேஷம் சொல்லுங்க?'],
        'Polite No': ['செய்திக்கு நன்றி, ஆனால் இது குறித்து என்னிடம் கருத்து எதுவும் இல்லை.', 'மன்னிக்கவும், இப்போது இந்த விஷயத்தில் நான் எதுவும் கூற முடியாது.'],
      },
    },
    'Telugu': {
      MessageIntent.greeting: {
        'Polite': ['చాలా రోజుల తర్వాత మాట్లాడటం జరిగింది. ఎలా సాగుతోంది?', 'మీ సందేశం రావడం చాలా సంతోషంగా ఉంది.'],
        'Friendly': ['హేయ్! ఎలా ఉన్నావు?', 'ఏంటి సంగతులు మిత్రమా? చాలా రోజుల తర్వాత గుర్తొచ్చానా!'],
        'Formal': ['మీతో సంప్రదించడం సంతోషంగా ఉంది. అంతా క్షేమమేనా?', 'నమస్కారం. మీరు క్షేమంగా ఉన్నారని భావిస్తున్నాను.'],
        'Direct': ['చెప్పండి, ఏమిటి విషయం?', 'నమస్కారం, దయచేసి మీ సమస్య ఏమిటో చెప్పండి.'],
        'Funny': ['ఏంటి బాస్! ఏం నడుస్తోంది?', 'ఎవరు వచ్చారు! మీకు ఏం సహాయం కావాలి?'],
        'Polite No': ['సందేశానికి ధన్యవాదాలు. నేను ఇప్పుడు కొంచెం బిజీగా ఉన్నాను.', 'నమస్కారం. ఇప్పుడు మాట్లాడలేను.'],
      },
      MessageIntent.request: {
        'Polite': ['నేను దీని కోసం తప్పకుండా ప్రయత్నిస్తాను. నాకు కొంచెం సమయం ఇవ్వండి.', 'మీ సమస్యను పరిష్కరించడానికి నా వంతు కృషి చేస్తాను.'],
        'Friendly': ['తప్పకుండా ఫ్రెండ్, నేను చేసి పెడతాను!', 'పర్లేదు మిత్రమా, నేను ఏం చేయగలనో చూస్తాను.'],
        'Formal': ['మీ అభ్యర్థన నమోదు చేయబడింది. మేము త్వరలోనే చర్యలు తీసుకుంటాము.', 'నేను ప్రాధాన్యత ఆధారంగా మీ అభ్యర్థనపై పని చేస్తున్నాను.'],
        'Direct': ['నేను దీనిపై పని చేస్తాను. వేచి ఉండండి.', 'సరే, చెప్పిన సమయానికి పని పూర్తవుతుంది.'],
        'Funny': ['నాలాంటి బద్ధకస్థుడితో పని చేయిస్తున్నారా? సరే కానీయండి!', 'పని అవుతుంది కానీ, బిర్యానీ ఎప్పుడు తినిపిస్తున్నారు?'],
        'Polite No': ['క్షమించండి, నేను ఇప్పుడు ఈ పనిలో సహాయం చేయలేను.', 'మరికొన్ని పనుల వల్ల నేను ఈ అభ్యర్థనను అంగీకరించలేకపోతున్నాను.'],
      },
      MessageIntent.invitation: {
        'Polite': ['ఆహ్వానానికి ధన్యవాదాలు. నేను రావడానికి ప్రయత్నిస్తాను.', 'ఆహ్వానించినందుకు కృతజ్ఞతలు. తప్పకుండా వస్తాను.'],
        'Friendly': ['తప్పకుండా వస్తాను ఫ్రెండ్! పార్టీ మిస్ చేసుకోలేను!', 'నన్ను కూడా ఉన్నట్లే లెక్కించు! రచ్చ చేద్దాం!'],
        'Formal': ['ఆహ్వానానికి ధన్యవాదాలు. నా షెడ్యూల్ ప్రకారం పాల్గొనడానికి ప్రయత్నిస్తాను.', 'కార్యక్రమానికి ఆహ్వానించినందుకు కృతజ్ఞతలు.'],
        'Direct': ['సరే, నేను వస్తాను.', 'ఆహ్వానాన్ని అంగీకరిస్తున్నాను. కలుద్దాం.'],
        'Funny': ['ఉచిత భోజనం ఉంటే అడగాల్సిన పని లేదు, నేను వచ్చేస్తా!', 'పార్టీని కలపడానికి నేను వస్తున్నాను, డోంట్ వర్రీ!'],
        'Polite No': ['ముందే నిశ్చయించుకున్న పని ఉండటం వల్ల నేను రాలేకపోతున్నాను.', 'క్షమించండి, ఇతర పనుల వల్ల నేను హాజరు కాలేకపోతున్నాను.'],
      },
      MessageIntent.apology: {
        'Polite': ['పొరపాటు జరిగినందుకు నేను మనస్ఫూర్తిగా క్షమాపణలు కోరుతున్నాను.', 'జరిగిన అసౌకర్యానికి దయచేసి నా క్షమాపణలు అంగీకరించండి.'],
        'Friendly': ['క్షమించు ఫ్రెండ్, తప్పు జరిగిపోయింది!', 'తెలియక జరిగింది మిత్రమా! ఇంక కోపం తగ్గించుకో!'],
        'Formal': ['ఈ పొరపాటుకు మేము విచారిస్తున్నాము మరియు సరిదిద్దడానికి చర్యలు తీసుకుంటున్నాము.', 'సేవల్లో జరిగిన ఈ లోపానికి దయచేసి మా క్షమాపణలు అంగీకరించండి.'],
        'Direct': ['నా పొరపాటే. నేను దీనిని వెంటనే సరి చేస్తాను.', 'క్షమించండి. మళ్లీ ఇలా జరగదు.'],
        'Funny': ['గుంజీలు తీయమంటారా ఏంటి? క్షమించండి బాస్!', 'నేను కూడా మనిషినే కదా, తప్పులు జరగడం సహజమే కదా! కోపపడకండి!'],
        'Polite No': ['క్షమించండి, కానీ ఈ విషయంలో ఇదే నా తుది నిర్ణయం.', 'విచారిస్తున్నాను, కానీ పరిస్థితులను బట్టి నా నిర్ణయం సరైనదే.'],
      },
      MessageIntent.complaint: {
        'Polite': ['ఇది దురదృష్టకరం. నేను దీనిని పరిష్కరించడానికి ఏర్పాట్లు చేస్తాను.', 'మీకు జరిగిన అసౌకర్యానికి విచారిస్తున్నాము. వెంటనే సరి చేస్తాము.'],
        'Friendly': ['చాలా చిరాగ్గా ఉంది మిత్రమా! నేను ఏం చేయగలనో చూస్తాను.', 'బాధగా ఉంది ఫ్రెండ్, ఇది సరికాదు. నేను చెక్ చేస్తాను.'],
        'Formal': ['మేము ఈ విషయంపై తక్షణమే విచారణ చేపడుతున్నాము.', 'మీ ఫిర్యాదు ఉన్నతాధికారుల పరిశీలనకు పంపబడింది.'],
        'Direct': ['ఇది ఆమోదయోగ్యం కాదు. వెంటనే సరి చేయమని ఆదేశిస్తున్నాను.', 'ఫిర్యాదు స్వీకరించబడింది. తక్షణ చర్యలు తీసుకోబడతాయి.'],
        'Funny': ['అంతా గందరగోళంగా తయారైంది! సరే, దీనిని సరి చేద్దాం.', 'ఇది ఎవరు పాడు చేశారో నేను కనుగొంటాను.'],
        'Polite No': ['మీ అసంతృప్తిని మేము అర్థం చేసుకున్నాము, కానీ మేము నిబంధనలను పాటించాలి.', 'ఫిర్యాదుకు ధన్యవాదాలు, కానీ ఇందులో ఎలాంటి మార్పులు సాధ్యపడవు.'],
      },
      MessageIntent.paymentReminder: {
        'Polite': ['బకాయిల చెల్లింపునకు సంబంధించిన చిన్న రిమైండర్.', 'దయచేసి పేమెంట్ స్టేటస్ చెక్ చేయగలరా?'],
        'Friendly': ['మిత్రమా, కొంచెం పేమెంట్ ఈరోజు ట్రాన్స్ ఫర్ చేయగలవా!', 'టైమ్ కి బిల్ క్లియర్ చేస్తే బాగుంటుంది ఫ్రెండ్!'],
        'Formal': ['దయచేసి సేవల బకాయిలను వీలైనంత త్వరగా చెల్లించాల్సిందిగా అభ్యర్థిస్తున్నాము.', 'ఇది పేమెంట్ కు సంబంధించిన ఒక అధికారిక రిమైండర్.'],
        'Direct': ['దయచేసి బకాయిలు చెల్లించండి. వివరాలు పైన ఉన్నాయి.', 'ఈరోజే పేమెంట్ చేయాలి. దయచేసి క్లియర్ చేయండి.'],
        'Funny': ['డబ్బులే ముఖ్యం బాస్! త్వరగా పంపించండి!', 'పని ఇష్టమే కానీ, డబ్బులు ఇంకా చాలా ఇష్టం! క్లియర్ చేయండి!'],
        'Polite No': ['విచారిస్తున్నాము, పేమెంట్ పూర్తయ్యే వరకు మేము తదుపరి పని చేయలేము.', 'నిబంధనల ప్రకారం, ఈ పేమెంట్ చెల్లింపు గడువును పొడిగించలేము.'],
      },
      MessageIntent.work: {
        'Polite': ['నేను నివేదికను సిద్ధం చేస్తున్నాను, త్వరలోనే పంపుతాను.', 'సమావేశం ఎజెండా సిద్ధంగా ఉంది. సరైన సమయానికి ప్రారంభిద్దాం.'],
        'Friendly': ['పనిలోనే ఉన్నాను ఫ్రెండ్! త్వరలోనే పంపుతాను, చిల్ అవ్వు!', 'బాస్ కి చూపించే ముందు ఒకసారి నేను చెక్ చేసుకుంటాను.'],
        'Formal': ['ప్రాజెక్ట్ గడువును అందుకోవడానికి అన్ని ప్రయత్నాలు జరుగుతున్నాయి.', 'ఈరోజు సమావేశం వివరాలు ఇమెయిల్ ద్వారా పంపబడతాయి.'],
        'Direct': ['పని జరుగుతోంది. గడువులోగా పూర్తవుతుంది.', 'నివేదిక సిద్ధంగా ఉంది. మీ ఇమెయిల్ చెక్ చేసుకోండి.'],
        'Funny': ['ఉద్యోగం చేయడం తప్పనిసరి కదా, ఏం చేస్తాం!', 'కోడింగ్ చేస్తే బిర్యానీ వస్తే ఎంత బాగుంటుందో! పని జరుగుతోంది!'],
        'Polite No': ['పనిభారం ఎక్కువగా ఉండటం వల్ల నేను ఈ కొత్త బాధ్యతను తీసుకోలేను.', 'అత్యవసర పని ఉండటం వల్ల ఈరోజు సమావేశానికి హాజరు కాలేకపోతున్నాను.'],
      },
      MessageIntent.customerQuery: {
        'Polite': ['ధర మరియు ఇతర వివరాలు మీ ఇన్ బాక్స్ కి పంపబడ్డాయి.', 'ఈ వస్తువు ప్రస్తుతం స్టాక్ లో ఉంది మరియు పంపడానికి సిద్ధంగా ఉంది.'],
        'Friendly': ['ధర చాలా తక్కువ బ్రదర్! ఆర్డర్ చేయడానికి ఇన్ బాక్స్ చేయండి!', 'మా వద్ద చాలా రంగులు మరియు సైజులు ఉన్నాయి. మీకు ఏది కావాలో చెప్పండి?'],
        'Formal': ['దయచేసి జతచేయబడిన ధరల పట్టిక మరియు డెలివరీ షరతులను చూడండి.', 'ప్రశ్నకు ధన్యవాదాలు. వస్తువు 3 రోజుల్లో పంపబడుతుంది.'],
        'Direct': ['ధర 1,200 రూపాయలు. క్యాష్ ఆన్ డెలివరీ అందుబాటులో ఉంది.', 'స్టాక్ తక్కువగా ఉంది. ఆర్డర్ చేయడానికి పేరు మరియు ఫోన్ నంబర్ పంపండి.'],
        'Funny': ['ధర విని షాక్ అవ్వకండి, క్వాలిటీ చాలా బాగుంటుంది!', 'చాలా చౌకైనది మరియు ఉత్తమమైనది! ఈరోజే తీసుకెళ్ళండి బాస్!'],
        'Polite No': ['విచారిస్తున్నాము, ఈ వస్తువు ప్రస్తుతం అందుబాటులో లేదు మరియు నిలిపివేయబడింది.', 'విచారిస్తున్నాము, ప్రస్తుతానికి ఎలాంటి డిస్కౌంట్లు అందుబాటులో లేవు.'],
      },
      MessageIntent.boundary: {
        'Polite': ['దయచేసి కార్యాలయ సమయం తర్వాత నన్ను సంప్రదించవద్దు.', 'మన సంభాషణలను కేవలం వృత్తిపరంగా మాత్రమే ఉంచాలని కోరుకుంటున్నాను.'],
        'Friendly': ['మిత్రమా, పని విషయం మాత్రమే మాట్లాడదాం, అనవసర విషయాలు వద్దు.', 'నా వ్యక్తిగత విషయాలు పంచుకోవడానికి ఇష్టపడను, థాంక్స్.'],
        'Formal': ['భవిష్యత్తు సంభాషణల కోసం దయచేసి అధికారిక మార్గాలను ఉపయోగించండి.', 'ఈ ప్రశ్న మన ఒప్పందం పరిధికి అతీతమైనది.'],
        'Direct': ['దయచేసి నాకు మళ్లీ ఫోన్ చేయవద్దు లేదా సందేశం పంపవద్దు.', 'దీనితో ఈ సంభాషణను ముగించాలనుకుంటున్నాను.'],
      },
      MessageIntent.appreciation: {
        'Polite': ['మీ మంచి మాటలకు ధన్యవాదాలు. చాలా అభినందనీయం.', 'మీ మద్దతు మరియు అభిప్రాయాలకు నేను కృతజ్ఞుడను.'],
        'Friendly': ['చాలా థాంక్స్ మిత్రమా! నువ్వు తోపు అంతే!', 'చాలా కృతజ్ఞతలు ఫ్రెండ్! ఎల్లప్పుడూ తోడుగా ఉన్నందుకు ధన్యవాదాలు!'],
        'Formal': ['మీ అభిప్రాయాన్ని మేము అభినందిస్తున్నాము మరియు మీకు సేవ చేయడానికి ఎదురుచూస్తున్నాము.', 'మాపై నమ్మకం ఉంచినందుకు ధన్యవాదాలు.'],
        'Direct': ['ధన్యవాదాలు. మీ సహాయం చాలా ఉపయోగపడింది.', 'కృతజ్ఞతలు.'],
        'Funny': ['పొగుడుతూనే ఉండు ఫ్రెండ్, నాకు చాలా ఇష్టం!', 'పొగడ్తలు విని గుండె నిండిపోయింది బాస్! ట్రీట్ ఎప్పుడు?'],
        'Polite No': ['అభినందనలకు ధన్యవాదాలు, కానీ నేను ఈ ప్రతిపాదనను అంగీకరించలేను.', 'అభినందనలకు ధన్యవాదాలు, కానీ నా నిర్ణయంలో మార్పు లేదు.'],
      },
      MessageIntent.general: {
        'Polite': ['నేను పరిస్థితిని అర్థం చేసుకున్నాను. సమాచారానికి ధన్యవాదాలు.', 'సరే. నేను త్వరలోనే మిమ్మల్ని మళ్లీ సంప్రదిస్తాను.'],
        'Friendly': ['అర్థమైంది ఫ్రెండ్! తర్వాత మాట్లాడదాం.', 'సరే మిత్రమా, చిల్! తర్వాత కలుద్దాం.'],
        'Formal': ['మీ సందేశం అందింది. వివరాలను త్వరలోనే మీకు తెలియజేస్తాము.', 'సమాచారాన్ని పంచుకున్నందుకు ధన్యవాదాలు.'],
        'Direct': ['అర్థమైంది. తదుపరి అప్‌డేట్ త్వరలోనే వస్తుంది.', 'అందింది. చర్యలు తీసుకుంటున్నాను.'],
        'Funny': ['కథ అర్థమైంది కానీ, కాఫీ ఎవరు ఇప్పిస్తున్నారు?', 'హహా, సూపర్! తర్వాత ఏంటి సంగతులు చెప్పండి?'],
        'Polite No': ['సందేశానికి ధನ್ಯవాదాలు, కానీ దీనిపై నా అభిప్రায়ం ఏమీ లేదు.', 'క్షమించండి, ఇప్పుడు ఈ విషయంపై నేను ఏమీ మాట్లాడలేను.'],
      },
    }
  };
}
