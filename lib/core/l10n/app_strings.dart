/// UI strings for the app interface (Somali default, English secondary).
///
/// Flutter's built-in Material localizations do not include Somali, so the
/// interface copy is kept here. Religious content (Arabic text, Somali
/// translations) always comes from the API, never from this file.
///
/// NOTE: The Somali copy should be reviewed by a native speaker before
/// release.
class AppStrings {
  const AppStrings(this.languageCode);

  final String languageCode;

  bool get isSomali => languageCode == 'so';

  String _t(String key) => (_values[languageCode] ?? _values['so']!)[key] ?? _values['en']![key] ?? key;

  String get appName => 'Xadiis App';
  String get tagline => _t('tagline');
  String get getStarted => _t('getStarted');
  String get next => _t('next');
  String get skip => _t('skip');
  String get onb1Title => _t('onb1Title');
  String get onb1Body => _t('onb1Body');
  String get onb2Title => _t('onb2Title');
  String get onb2Body => _t('onb2Body');
  String get onb3Title => _t('onb3Title');
  String get onb3Body => _t('onb3Body');
  String get onb4Title => _t('onb4Title');
  String get onb4Body => _t('onb4Body');

  String get navHome => _t('navHome');
  String get navCollections => _t('navCollections');
  String get navSearch => _t('navSearch');
  String get navMemorize => _t('navMemorize');
  String get navProfile => _t('navProfile');

  String get welcome => _t('welcome');
  String welcomeName(String name) => _t('welcomeName').replaceAll('{name}', name);
  String get welcomeSubtitle => _t('welcomeSubtitle');
  String get searchHint => _t('searchHint');
  String get hadithOfTheDay => _t('hadithOfTheDay');
  String get noHadithOfTheDay => _t('noHadithOfTheDay');
  String get popularCollections => _t('popularCollections');
  String get topics => _t('topics');
  String get recentlyViewed => _t('recentlyViewed');
  String get noRecent => _t('noRecent');
  String get seeAll => _t('seeAll');
  String get memorizeShortcutTitle => _t('memorizeShortcutTitle');
  String get memorizeShortcutBody => _t('memorizeShortcutBody');

  String get collections => _t('collections');
  String get chapters => _t('chapters');
  String get hadiths => _t('hadiths');
  String get chapter => _t('chapter');
  String get noChapters => _t('noChapters');
  String get noHadiths => _t('noHadiths');
  String get offlineCollections => _t('offlineCollections');
  String hadithNo(String n) => _t('hadithNo').replaceAll('{n}', n);
  String get allHadiths => _t('allHadiths');

  String get arabicText => _t('arabicText');
  String get somaliTranslation => _t('somaliTranslation');
  String get noTranslation => _t('noTranslation');
  String get grading => _t('grading');
  String get gradedBy => _t('gradedBy');
  String get source => _t('source');
  String get explanation => _t('explanation');
  String get narrator => _t('narrator');
  String get reference => _t('reference');
  String get textSize => _t('textSize');
  String get share => _t('share');
  String get addFavorite => _t('addFavorite');
  String get removeFavorite => _t('removeFavorite');
  String get addToMemorization => _t('addToMemorization');
  String get addedToMemorization => _t('addedToMemorization');
  String get translator => _t('translator');

  String get search => _t('search');
  String get searchEmptyPrompt => _t('searchEmptyPrompt');
  String get noResults => _t('noResults');
  String get searchByHint => _t('searchByHint');
  String get allCollections => _t('allCollections');

  String get favorites => _t('favorites');
  String get noFavorites => _t('noFavorites');

  String get memorization => _t('memorization');
  String get dailyGoal => _t('dailyGoal');
  String dailyGoalValue(int n) => _t('dailyGoalValue').replaceAll('{n}', '$n');
  String get dueForReview => _t('dueForReview');
  String get learned => _t('learned');
  String get inProgress => _t('inProgress');
  String get progress => _t('progress');
  String get startReview => _t('startReview');
  String get nothingDue => _t('nothingDue');
  String get memorizationLoginPrompt => _t('memorizationLoginPrompt');
  String get noMemorization => _t('noMemorization');
  String get reviewSession => _t('reviewSession');
  String get showTranslation => _t('showTranslation');
  String get howWell => _t('howWell');
  String get rateAgain => _t('rateAgain');
  String get rateHard => _t('rateHard');
  String get rateGood => _t('rateGood');
  String get rateEasy => _t('rateEasy');
  String get reviewDone => _t('reviewDone');
  String get quiz => _t('quiz');
  String get quizComingSoon => _t('quizComingSoon');

  String get profile => _t('profile');
  String get guest => _t('guest');
  String get guestBody => _t('guestBody');
  String get login => _t('login');
  String get register => _t('register');
  String get logout => _t('logout');
  String get email => _t('email');
  String get password => _t('password');
  String get displayName => _t('displayName');
  String get noAccount => _t('noAccount');
  String get haveAccount => _t('haveAccount');
  String get invalidEmail => _t('invalidEmail');
  String get passwordTooShort => _t('passwordTooShort');
  String get requiredField => _t('requiredField');
  String get settings => _t('settings');
  String get language => _t('language');
  String get theme => _t('theme');
  String get themeSystem => _t('themeSystem');
  String get themeLight => _t('themeLight');
  String get themeDark => _t('themeDark');
  String get notifications => _t('notifications');
  String get notifyDaily => _t('notifyDaily');
  String get notifyReviews => _t('notifyReviews');
  String get notificationsNote => _t('notificationsNote');
  String get readingHistory => _t('readingHistory');
  String get clearHistory => _t('clearHistory');
  String get about => _t('about');
  String get contentNotice => _t('contentNotice');

  String get retry => _t('retry');
  String get errorGeneric => _t('errorGeneric');
  String get errorNetwork => _t('errorNetwork');
  String get loginRequired => _t('loginRequired');
  String get loading => _t('loading');

  static const Map<String, Map<String, String>> _values = {
    'so': {
      'tagline': 'Akhri, Fahan, Baro, Xifdi.',
      'getStarted': 'Bilow',
      'next': 'Xiga',
      'skip': 'Ka bood',
      'onb1Title': 'Ku akhri Carabi iyo Soomaali',
      'onb1Body': 'Xadiisyada ku akhri qoraalkooda asalka ah ee Carabiga iyo tarjumaad Soomaali ah.',
      'onb2Title': 'Fahan macnaha',
      'onb2Body': 'Hel sharraxaad la hubiyey iyo tixraacyada xadiis kasta.',
      'onb3Title': 'Baro casharrada Islaamka',
      'onb3Body': 'Ku baadh xadiisyada mawduucyo sida salaadda, akhlaaqda iyo qoyska.',
      'onb4Title': 'Xifdi oo dib u eeg',
      'onb4Body': 'Dejiso hadaf maalinle ah, la soco horumarkaaga, oo dib u eeg waqtiga ku habboon.',
      'navHome': 'Hoyga',
      'navCollections': 'Kutubta',
      'navSearch': 'Raadi',
      'navMemorize': 'Xifdi',
      'navProfile': 'Aniga',
      'welcome': 'Assalaamu calaykum',
      'welcomeName': 'Assalaamu calaykum, {name}',
      'welcomeSubtitle': 'Maanta maxaad baran doontaa?',
      'searchHint': 'Raadi xadiis, mawduuc ama lambar…',
      'hadithOfTheDay': 'Xadiiska Maanta',
      'noHadithOfTheDay': 'Weli lama daabicin xadiis la hubiyey. Fadlan dib u soo laabo.',
      'popularCollections': 'Kutubta caanka ah',
      'topics': 'Mawduucyada',
      'recentlyViewed': 'Dhowaan la akhriyey',
      'noRecent': 'Xadiisyada aad akhrido halkan ayay ka soo muuqan doonaan.',
      'seeAll': 'Dhammaan',
      'memorizeShortcutTitle': 'Xifdinta maanta',
      'memorizeShortcutBody': 'Dib u eeg xadiisyada lagaa rabo maanta.',
      'collections': 'Kutubta Xadiiska',
      'chapters': 'Cutubyada',
      'hadiths': 'Xadiisyada',
      'chapter': 'Cutub',
      'noChapters': 'Cutubyo la hubiyey weli lama heli karo.',
      'noHadiths': 'Xadiis la hubiyey weli laguma darin halkan.',
      'offlineCollections': 'Ma xidhiidhi kartid server-ka. Cutubyada iyo xadiisyada waxay u baahan yihiin internet.',
      'hadithNo': 'Xadiis {n}',
      'allHadiths': 'Dhammaan xadiisyada',
      'arabicText': 'Qoraalka Carabiga',
      'somaliTranslation': 'Tarjumaadda Soomaaliga',
      'noTranslation': 'Tarjumaad Soomaali ah oo la hubiyey weli lama heli karo.',
      'grading': 'Darajada',
      'gradedBy': 'Waxaa qiimeeyey',
      'source': 'Tixraac',
      'explanation': 'Sharraxaad',
      'narrator': 'Wariye',
      'reference': 'Tixraaca',
      'textSize': 'Cabbirka qoraalka',
      'share': 'La wadaag',
      'addFavorite': 'Ku dar kuwa la jecel yahay',
      'removeFavorite': 'Ka saar kuwa la jecel yahay',
      'addToMemorization': 'Ku dar xifdinta',
      'addedToMemorization': 'Waa lagu daray xifdinta',
      'translator': 'Turjubaan',
      'search': 'Raadi',
      'searchEmptyPrompt': 'Ku raadi qoraal Carabi, tarjumaad Soomaali, magaca kitaabka ama lambarka xadiiska.',
      'noResults': 'Wax natiijo ah lama helin.',
      'searchByHint': 'Carabi, Soomaali, kitaab ama lambar',
      'allCollections': 'Dhammaan kutubta',
      'favorites': 'Kuwa la jecel yahay',
      'noFavorites': 'Weli wax xadiis ah kuma kaydin. Taabo calaamadda wadnaha si aad u kaydiso.',
      'memorization': 'Xifdinta',
      'dailyGoal': 'Hadafka maalinlaha',
      'dailyGoalValue': '{n} xadiis maalintii',
      'dueForReview': 'Dib-u-eegis la gaadhay',
      'learned': 'La xifdiyey',
      'inProgress': 'Socda',
      'progress': 'Horumarka',
      'startReview': 'Bilow dib-u-eegista',
      'nothingDue': 'Maanta wax dib-u-eegis ah lagaa rabo ma jiro.',
      'memorizationLoginPrompt': 'Gal akoonkaaga si horumarka xifdintaadu u kaydsamo oo qalab kasta uga muuqdo.',
      'noMemorization': 'Weli xadiis kuma darin xifdinta. Fur xadiis kadibna taabo "Ku dar xifdinta".',
      'reviewSession': 'Dib-u-eegis',
      'showTranslation': 'Muuji tarjumaadda',
      'howWell': 'Intee in le\'eg ayaad u xasuusatay?',
      'rateAgain': 'Ma xasuusan',
      'rateHard': 'Adag',
      'rateGood': 'Fiican',
      'rateEasy': 'Fudud',
      'reviewDone': 'Mahadsanid! Dib-u-eegista maanta waa dhammaatay.',
      'quiz': 'Imtixaan is-qiimeyn',
      'quizComingSoon': 'Imtixaannada is-qiimeynta waxay imanayaan marxaladda xigta.',
      'profile': 'Aniga',
      'guest': 'Marti',
      'guestBody': 'Xadiisyada waad akhrin kartaa adigoon is diiwaangelin. Gal si aad u kaydiso horumarkaaga.',
      'login': 'Gal',
      'register': 'Is diiwaangeli',
      'logout': 'Ka bax',
      'email': 'Iimayl',
      'password': 'Furaha sirta',
      'displayName': 'Magacaaga',
      'noAccount': 'Akoon ma lihid? Is diiwaangeli',
      'haveAccount': 'Akoon ma leedahay? Gal',
      'invalidEmail': 'Geli iimayl sax ah',
      'passwordTooShort': 'Furaha sirtu waa inuu ahaadaa ugu yaraan 8 xaraf',
      'requiredField': 'Goobtan waa qasab',
      'settings': 'Dejinta',
      'language': 'Luqadda',
      'theme': 'Muuqaalka',
      'themeSystem': 'Sida qalabka',
      'themeLight': 'Iftiin',
      'themeDark': 'Mugdi',
      'notifications': 'Ogeysiisyada',
      'notifyDaily': 'Xadiiska maanta',
      'notifyReviews': 'Xasuusinta dib-u-eegista',
      'notificationsNote': 'Ogeysiisyada riixista (push) waxaa lagu dari doonaa marxaladda xigta.',
      'readingHistory': 'Taariikhda akhriska',
      'clearHistory': 'Tirtir taariikhda',
      'about': 'Ku saabsan',
      'contentNotice': 'Xadiis kasta waxaa la daabacaa kaliya kadib marka la hubiyo qoraalka, tarjumaadda iyo tixraaca.',
      'retry': 'Isku day mar kale',
      'errorGeneric': 'Wax qalad ah ayaa dhacay.',
      'errorNetwork': 'Lama gaadhi karo server-ka. Hubi internet-kaaga.',
      'loginRequired': 'Fadlan gal si aad u isticmaasho adeegan.',
      'loading': 'Waa la soo rarayaa…',
    },
    'en': {
      'tagline': 'Read, Understand, Learn, Memorize.',
      'getStarted': 'Get started',
      'next': 'Next',
      'skip': 'Skip',
      'onb1Title': 'Read in Arabic and Somali',
      'onb1Body': 'Read Hadiths in their original Arabic alongside a Somali translation.',
      'onb2Title': 'Understand the meaning',
      'onb2Body': 'Get verified explanations and references for each Hadith.',
      'onb3Title': 'Learn Islamic teachings',
      'onb3Body': 'Explore Hadiths by topics such as prayer, character and family.',
      'onb4Title': 'Memorize and review',
      'onb4Body': 'Set a daily goal, track your progress, and review at the right time.',
      'navHome': 'Home',
      'navCollections': 'Collections',
      'navSearch': 'Search',
      'navMemorize': 'Memorize',
      'navProfile': 'Profile',
      'welcome': 'Assalamu alaikum',
      'welcomeName': 'Assalamu alaikum, {name}',
      'welcomeSubtitle': 'What will you learn today?',
      'searchHint': 'Search hadith, topic or number…',
      'hadithOfTheDay': 'Hadith of the Day',
      'noHadithOfTheDay': 'No verified Hadith has been published yet. Please check back soon.',
      'popularCollections': 'Popular collections',
      'topics': 'Topics',
      'recentlyViewed': 'Recently viewed',
      'noRecent': 'Hadiths you read will appear here.',
      'seeAll': 'See all',
      'memorizeShortcutTitle': "Today's memorization",
      'memorizeShortcutBody': 'Review the Hadiths due today.',
      'collections': 'Hadith Collections',
      'chapters': 'Chapters',
      'hadiths': 'Hadiths',
      'chapter': 'Chapter',
      'noChapters': 'No verified chapters are available yet.',
      'noHadiths': 'No verified Hadiths have been added here yet.',
      'offlineCollections': 'Cannot reach the server. Chapters and Hadiths need a connection.',
      'hadithNo': 'Hadith {n}',
      'allHadiths': 'All Hadiths',
      'arabicText': 'Arabic text',
      'somaliTranslation': 'Somali translation',
      'noTranslation': 'No verified Somali translation is available yet.',
      'grading': 'Grading',
      'gradedBy': 'Graded by',
      'source': 'Source',
      'explanation': 'Explanation',
      'narrator': 'Narrator',
      'reference': 'Reference',
      'textSize': 'Text size',
      'share': 'Share',
      'addFavorite': 'Add to favorites',
      'removeFavorite': 'Remove from favorites',
      'addToMemorization': 'Add to memorization',
      'addedToMemorization': 'Added to memorization',
      'translator': 'Translator',
      'search': 'Search',
      'searchEmptyPrompt': 'Search by Arabic text, Somali translation, collection name or Hadith number.',
      'noResults': 'No results found.',
      'searchByHint': 'Arabic, Somali, collection or number',
      'allCollections': 'All collections',
      'favorites': 'Favorites',
      'noFavorites': 'No saved Hadiths yet. Tap the heart icon to save one.',
      'memorization': 'Memorization',
      'dailyGoal': 'Daily goal',
      'dailyGoalValue': '{n} hadith per day',
      'dueForReview': 'Due for review',
      'learned': 'Memorized',
      'inProgress': 'In progress',
      'progress': 'Progress',
      'startReview': 'Start review',
      'nothingDue': 'Nothing is due for review today.',
      'memorizationLoginPrompt': 'Sign in so your memorization progress is saved and synced across devices.',
      'noMemorization': 'No Hadiths added yet. Open a Hadith and tap "Add to memorization".',
      'reviewSession': 'Review',
      'showTranslation': 'Show translation',
      'howWell': 'How well did you remember it?',
      'rateAgain': 'Forgot',
      'rateHard': 'Hard',
      'rateGood': 'Good',
      'rateEasy': 'Easy',
      'reviewDone': "Well done! Today's review is complete.",
      'quiz': 'Self-assessment quiz',
      'quizComingSoon': 'Self-assessment quizzes are coming in the next phase.',
      'profile': 'Profile',
      'guest': 'Guest',
      'guestBody': 'You can read Hadiths without an account. Sign in to save your progress.',
      'login': 'Sign in',
      'register': 'Create account',
      'logout': 'Sign out',
      'email': 'Email',
      'password': 'Password',
      'displayName': 'Your name',
      'noAccount': "Don't have an account? Create one",
      'haveAccount': 'Already have an account? Sign in',
      'invalidEmail': 'Enter a valid email',
      'passwordTooShort': 'Password must be at least 8 characters',
      'requiredField': 'This field is required',
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'themeSystem': 'System',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'notifications': 'Notifications',
      'notifyDaily': 'Hadith of the day',
      'notifyReviews': 'Review reminders',
      'notificationsNote': 'Push notifications will be added in the next phase.',
      'readingHistory': 'Reading history',
      'clearHistory': 'Clear history',
      'about': 'About',
      'contentNotice': 'Each Hadith is published only after its text, translation and reference are verified.',
      'retry': 'Try again',
      'errorGeneric': 'Something went wrong.',
      'errorNetwork': 'Cannot reach the server. Check your connection.',
      'loginRequired': 'Please sign in to use this feature.',
      'loading': 'Loading…',
    },
  };
}
