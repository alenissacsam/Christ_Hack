import React, { createContext, useContext, useState, ReactNode } from 'react'

export type Language = 'en' | 'hi' | 'bn' | 'ta' | 'te' | 'gu' | 'mr' | 'kn' | 'ml' | 'or'

export interface LanguageOption {
  code: Language
  name: string
  nativeName: string
}

export const languageOptions: LanguageOption[] = [
  { code: 'en', name: 'English', nativeName: 'English' },
  { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी' },
  { code: 'bn', name: 'Bengali', nativeName: 'বাংলা' },
  { code: 'ta', name: 'Tamil', nativeName: 'தமிழ்' },
  { code: 'te', name: 'Telugu', nativeName: 'తెలుగు' },
  { code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી' },
  { code: 'mr', name: 'Marathi', nativeName: 'मराठी' },
  { code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ' },
  { code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം' },
  { code: 'or', name: 'Odia', nativeName: 'ଓଡ଼ିଆ' },
]

const translations = {
  en: {
    // App navigation
    home: 'Home',
    myStatus: 'My Status',
    verification: 'Verification',
    adminServices: 'Admin Services',
    settings: 'Settings',
    
    // Header
    digitalIdentityServices: 'Digital Identity Services',
    governmentOfIndia: 'Government of India',
    network: 'Network',
    
    // Settings page
    settingsTitle: 'Settings',
    networkSettings: 'Network and service addresses',
    userPreferences: 'User Preferences',
    privacySettings: 'Privacy Settings',
    notificationSettings: 'Notification Settings',
    liabilitySettings: 'Liability & Legal',
    dataRetention: 'Data Retention',
    
    // MyGov tabs
    discuss: 'Discuss',
    do: 'Do',
    pollSurvey: 'Poll/Survey',
    blog: 'Blog',
    talk: 'Talk',
    
    // Poll Survey
    identityDistribution: 'Identity Distribution Survey',
    aadhaarHolders: 'Aadhaar Holders',
    otherIdentityHolders: 'Other Identity Holders',
    noIdentity: 'No Identity Documents',
    
    // Settings options
    enableNotifications: 'Enable push notifications',
    dataCollection: 'Allow data collection for analytics',
    shareWithGov: 'Share data with government agencies',
    autoDelete: 'Auto-delete data after verification',
    acceptLiability: 'I accept liability for data accuracy',
    agreeTerms: 'I agree to terms and conditions',
    save: 'Save',
    saved: 'Saved!',
    
    // Footer
    footerText: 'Bharat Digital Public Infrastructure • Secure • Private',
  },
  hi: {
    // App navigation
    home: 'होम',
    myStatus: 'मेरी स्थिति',
    verification: 'सत्यापन',
    adminServices: 'प्रशासन सेवाएं',
    settings: 'सेटिंग्स',
    
    // Header
    digitalIdentityServices: 'डिजिटल पहचान सेवाएं',
    governmentOfIndia: 'भारत सरकार',
    network: 'नेटवर्क',
    
    // Settings page
    settingsTitle: 'सेटिंग्स',
    networkSettings: 'नेटवर्क और सेवा पते',
    userPreferences: 'उपयोगकर्ता प्राथमिकताएं',
    privacySettings: 'गोपनीयता सेटिंग्स',
    notificationSettings: 'सूचना सेटिंग्स',
    liabilitySettings: 'दायित्व और कानूनी',
    dataRetention: 'डेटा प्रतिधारण',
    
    // MyGov tabs
    discuss: 'चर्चा',
    do: 'करें',
    pollSurvey: 'मतदान/सर्वेक्षण',
    blog: 'ब्लॉग',
    talk: 'बात करें',
    
    // Poll Survey
    identityDistribution: 'पहचान वितरण सर्वेक्षण',
    aadhaarHolders: 'आधार धारक',
    otherIdentityHolders: 'अन्य पहचान धारक',
    noIdentity: 'कोई पहचान दस्तावेज नहीं',
    
    // Settings options
    enableNotifications: 'पुश नोटिफिकेशन सक्षम करें',
    dataCollection: 'विश्लेषण के लिए डेटा संग्रह की अनुमति दें',
    shareWithGov: 'सरकारी एजेंसियों के साथ डेटा साझा करें',
    autoDelete: 'सत्यापन के बाद डेटा को स्वतः हटाएं',
    acceptLiability: 'मैं डेटा सटीकता के लिए दायित्व स्वीकार करता हूं',
    agreeTerms: 'मैं नियम और शर्तों से सहमत हूं',
    save: 'सेव करें',
    saved: 'सेव किया गया!',
    
    // Footer
    footerText: 'भारत डिजिटल पब्लिक इन्फ्रास्ट्रक्चर • सुरक्षित • निजी',
  },
  // Add more languages as needed - for now keeping it simple with EN and HI
  bn: { home: 'হোম', myStatus: 'আমার অবস্থা', verification: 'যাচাইকরণ', adminServices: 'প্রশাসনিক সেবা', settings: 'সেটিংস', digitalIdentityServices: 'ডিজিটাল পরিচয় সেবা', governmentOfIndia: 'ভারত সরকার', network: 'নেটওয়ার্ক', settingsTitle: 'সেটিংস', networkSettings: 'নেটওয়ার্ক এবং সেবা ঠিকানা', userPreferences: 'ব্যবহারকারীর পছন্দ', privacySettings: 'গোপনীয়তা সেটিংস', notificationSettings: 'বিজ্ঞপ্তি সেটিংস', liabilitySettings: 'দায়বদ্ধতা এবং আইনি', dataRetention: 'ডেটা ধরে রাখা', discuss: 'আলোচনা', do: 'করুন', pollSurvey: 'জরিপ/সার্ভে', blog: 'ব্লগ', talk: 'কথা বলুন', identityDistribution: 'পরিচয় বিতরণ সর্ভে', aadhaarHolders: 'আধার ধারক', otherIdentityHolders: 'অন্যান্য পরিচয় ধারক', noIdentity: 'কোনো পরিচয় দস্তাবেজ নেই', enableNotifications: 'পুশ বিজ্ঞপ্তি সক্ষম করুন', dataCollection: 'বিশ্লেষণের জন্য ডেটা সংগ্রহের অনুমতি দিন', shareWithGov: 'সরকারি সংস্থার সাথে ডেটা শেয়ার করুন', autoDelete: 'যাচাইকরণের পর ডেটা স্বয়ংক্রিয়ভাবে মুছুন', acceptLiability: 'আমি ডেটা নির্ভুলতার জন্য দায়বদ্ধতা গ্রহণ করি', agreeTerms: 'আমি নিয়ম ও শর্তাবলীতে সম্মত', save: 'সংরক্ষণ করুন', saved: 'সংরক্ষিত!', footerText: 'ভারত ডিজিটাল পাবলিক ইনফ্রাস্ট্রাকচার • নিরাপদ • ব্যক্তিগত' },
  ta: { home: 'முகப்பு', myStatus: 'எனது நிலை', verification: 'சரிபார்ப்பு', adminServices: 'நிர்வாக சேவைகள்', settings: 'அமைப்புகள்', digitalIdentityServices: 'டிஜிட்டல் அடையாள சேவைகள்', governmentOfIndia: 'இந்திய அரசு', network: 'நெட்வொர்க்', settingsTitle: 'அமைப்புகள்', networkSettings: 'நெட்வொர்க் மற்றும் சேவை முகவரிகள்', userPreferences: 'பயனர் விருப்பத்தேர்வுகள்', privacySettings: 'தனியுரிமை அமைப்புகள்', notificationSettings: 'அறிவிப்பு அமைப்புகள்', liabilitySettings: 'பொறுப்பு மற்றும் சட்ட', dataRetention: 'தரவு தக்கவைப்பு', discuss: 'விவாதிக்க', do: 'செய்', pollSurvey: 'கருத்துக்கணிப்பு/ஆய்வு', blog: 'வலைப்பதிவு', talk: 'பேச', identityDistribution: 'அடையாள விநியோக ஆய்வு', aadhaarHolders: 'ஆதார் வைத்திருப்பவர்கள்', otherIdentityHolders: 'மற்ற அடையாள வைத்திருப்பவர்கள்', noIdentity: 'அடையாள ஆவணங்கள் இல்லை', enableNotifications: 'புஷ் அறிவிப்புகளை இயக்கு', dataCollection: 'பகுப்பாய்வுக்கான தரவு சேகரிப்பை அனுமதி', shareWithGov: 'அரசு நிறுவனங்களுடன் தரவை பகிர்', autoDelete: 'சரிபார்ப்புக்குப் பிறகு தரவை தானாக நீக்கு', acceptLiability: 'தரவு துல்லியத்திற்கான பொறுப்பை ஏற்கிறேன்', agreeTerms: 'நான் விதிமுறைகளுக்கு ஒப்புக்கொள்கிறேன்', save: 'சேமி', saved: 'சேமிக்கப்பட்டது!', footerText: 'பாரத் டிஜிட்டல் பொது உள்கட்டமைப்பு • பாதுகாப்பான • தனிப்பட்ட' },
  te: { home: 'హోమ్', myStatus: 'నా స్టేటస్', verification: 'ధృవీకరణ', adminServices: 'అడ్మిన్ సేవలు', settings: 'సెట్టింగులు', digitalIdentityServices: 'డిజిటల్ గుర్తింపు సేవలు', governmentOfIndia: 'భారత ప్రభుత్వం', network: 'నెట్‌వర్క్', settingsTitle: 'సెట్టింగులు', networkSettings: 'నెట్‌వర్క్ మరియు సేవా చిరునామాలు', userPreferences: 'వినియోగదారు ప్రాధాన్యతలు', privacySettings: 'గోప్యత సెట్టింగులు', notificationSettings: 'నోటిఫికేషన్ సెట్టింగులు', liabilitySettings: 'బాధ్యత మరియు చట్టపరమైన', dataRetention: 'డేటా నిలుపుదల', discuss: 'చర్చించు', do: 'చేయి', pollSurvey: 'పోల్/సర్వే', blog: 'బ్లాగ్', talk: 'మాట్లాడు', identityDistribution: 'గుర్తింపు పంపిణీ సర్వే', aadhaarHolders: 'ఆధార్ కలిగిన వారు', otherIdentityHolders: 'ఇతర గుర్తింపు కలిగిన వారు', noIdentity: 'గుర్తింపు పత్రాలు లేవు', enableNotifications: 'పుష్ నోటిఫికేషన్లను ప్రారంభించండి', dataCollection: 'విశ్లేషణల కోసం డేటా సేకరణను అనుమతించండి', shareWithGov: 'ప్రభుత్వ సంస్థలతో డేటాను పంచుకోండి', autoDelete: 'ధృవీకరణ తర్వాత డేటాను స్వయంచాలకంగా తొలగించండి', acceptLiability: 'నేను డేటా ఖచ్చితత్వానికి బాధ్యత వహిస్తాను', agreeTerms: 'నేను నియమాలు మరియు షరతులను అంగీకరిస్తున్నాను', save: 'సేవ్ చేయండి', saved: 'సేవ్ చేయబడింది!', footerText: 'భారత్ డిజిటల్ పబ్లిక్ ఇన్‌ఫ్రాస్ట్రక్చర్ • సురక్షితమైన • ప్రైవేట్' },
  gu: { home: 'હોમ', myStatus: 'મારી સ્થિતિ', verification: 'ચકાસણી', adminServices: 'વહીવટી સેવાઓ', settings: 'સેટિંગ્સ', digitalIdentityServices: 'ડિજિટલ ઓળખ સેવાઓ', governmentOfIndia: 'ભારત સરકાર', network: 'નેટવર્ક', settingsTitle: 'સેટિંગ્સ', networkSettings: 'નેટવર્ક અને સેવા સરનામાં', userPreferences: 'વપરાશકર્તાની પસંદગીઓ', privacySettings: 'ગોપનીયતા સેટિંગ્સ', notificationSettings: 'નોટિફિકેશન સેટિંગ્સ', liabilitySettings: 'જવાબદારી અને કાનૂની', dataRetention: 'ડેટા રીટેન્શન', discuss: 'ચર્ચા', do: 'કરો', pollSurvey: 'મતદાન/સર્વે', blog: 'બ્લોગ', talk: 'વાત કરો', identityDistribution: 'ઓળખ વિતરણ સર્વે', aadhaarHolders: 'આધાર ધારકો', otherIdentityHolders: 'અન્ય ઓળખ ધારકો', noIdentity: 'કોઈ ઓળખ દસ્તાવેજો નથી', enableNotifications: 'પુશ નોટિફિકેશન સક્ષમ કરો', dataCollection: 'વિશ્લેષણ માટે ડેટા સંગ્રહની મંજૂરી આપો', shareWithGov: 'સરકારી એજન્સીઓ સાથે ડેટા શેર કરો', autoDelete: 'ચકાસણી પછી ડેટા આપોઆપ કાઢી નાખો', acceptLiability: 'હું ડેટાની સચોટતા માટે જવાબદારી સ્વીકારું છું', agreeTerms: 'હું નિયમો અને શરતો સાથે સહમત છું', save: 'સેવ કરો', saved: 'સેવ થયું!', footerText: 'ભારત ડિજિટલ પબ્લિક ઇન્ફ્રાસ્ટ્રક્ચર • સુરક્ષિત • ખાનગી' },
  mr: { home: 'होम', myStatus: 'माझी स्थिती', verification: 'पडताळणी', adminServices: 'प्रशासकीय सेवा', settings: 'सेटिंग्स', digitalIdentityServices: 'डिजिटल ओळख सेवा', governmentOfIndia: 'भारत सरकार', network: 'नेटवर्क', settingsTitle: 'सेटिंग्स', networkSettings: 'नेटवर्क आणि सेवा पत्ते', userPreferences: 'वापरकर्ता प्राधान्ये', privacySettings: 'गोपनीयता सेटिंग्स', notificationSettings: 'सूचना सेटिंग्स', liabilitySettings: 'जबाबदारी आणि कायदेशीर', dataRetention: 'डेटा धारणा', discuss: 'चर्चा', do: 'करा', pollSurvey: 'मतदान/सर्वेक्षण', blog: 'ब्लॉग', talk: 'बोला', identityDistribution: 'ओळख वितरण सर्वेक्षण', aadhaarHolders: 'आधार धारक', otherIdentityHolders: 'इतर ओळख धारक', noIdentity: 'कोणतेही ओळख कागदपत्र नाहीत', enableNotifications: 'पुश सूचना सक्षम करा', dataCollection: 'विश्लेषणासाठी डेटा संकलनास परवानगी द्या', shareWithGov: 'सरकारी एजन्सींसह डेटा सामायिक करा', autoDelete: 'पडताळणीनंतर डेटा आपोआप हटवा', acceptLiability: 'मी डेटा अचूकतेसाठी जबाबदारी स्वीकारतो', agreeTerms: 'मी नियम व अटींशी सहमत आहे', save: 'जतन करा', saved: 'जतन केले!', footerText: 'भारत डिजिटल सार्वजनिक पायाभूत सुविधा • सुरक्षित • खाजगी' },
  kn: { home: 'ಮುಖಪುಟ', myStatus: 'ನನ್ನ ಸ್ಥಿತಿ', verification: 'ಪರಿಶೀಲನೆ', adminServices: 'ನಿರ್ವಾಹಕ ಸೇವೆಗಳು', settings: 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು', digitalIdentityServices: 'ಡಿಜಿಟಲ್ ಗುರುತು ಸೇವೆಗಳು', governmentOfIndia: 'ಭಾರತ ಸರ್ಕಾರ', network: 'ನೆಟ್‌ವರ್ಕ್', settingsTitle: 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು', networkSettings: 'ನೆಟ್‌ವರ್ಕ್ ಮತ್ತು ಸೇವಾ ವಿಳಾಸಗಳು', userPreferences: 'ಬಳಕೆದಾರರ ಆದ್ಯತೆಗಳು', privacySettings: 'ಗೌಪ್ಯತೆ ಸೆಟ್ಟಿಂಗ್‌ಗಳು', notificationSettings: 'ಅಧಿಸೂಚನೆ ಸೆಟ್ಟಿಂಗ್‌ಗಳು', liabilitySettings: 'ಹೊಣೆಗಾರಿಕೆ ಮತ್ತು ಕಾನೂನು', dataRetention: 'ಡೇಟಾ ಧಾರಣೆ', discuss: 'ಚರ್ಚಿಸಿ', do: 'ಮಾಡಿ', pollSurvey: 'ಮತದಾನ/ಸರ್ವೆ', blog: 'ಬ್ಲಾಗ್', talk: 'ಮಾತನಾಡಿ', identityDistribution: 'ಗುರುತು ವಿತರಣಾ ಸರ್ವೆ', aadhaarHolders: 'ಆಧಾರ್ ಹೊಂದಿದವರು', otherIdentityHolders: 'ಇತರ ಗುರುತು ಹೊಂದಿದವರು', noIdentity: 'ಯಾವುದೇ ಗುರುತು ದಾಖಲೆಗಳಿಲ್ಲ', enableNotifications: 'ಪುಷ್ ಅಧಿಸೂಚನೆಗಳನ್ನು ಸಕ್ರಿಯಗೊಳಿಸಿ', dataCollection: 'ವಿಶ್ಲೇಷಣೆಗಾಗಿ ಡೇಟಾ ಸಂಗ್ರಹಣೆಗೆ ಅನುಮತಿಸಿ', shareWithGov: 'ಸರ್ಕಾರಿ ಏಜೆನ್ಸಿಗಳೊಂದಿಗೆ ಡೇಟಾ ಹಂಚಿಕೊಳ್ಳಿ', autoDelete: 'ಪರಿಶೀಲನೆಯ ನಂತರ ಡೇಟಾವನ್ನು ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಅಳಿಸಿ', acceptLiability: 'ಡೇಟಾ ನಿಖರತೆಗಾಗಿ ನಾನು ಹೊಣೆಗಾರಿಕೆಯನ್ನು ಸ್ವೀಕರಿಸುತ್ತೇನೆ', agreeTerms: 'ನಾನು ನಿಯಮಗಳು ಮತ್ತು ಷರತ್ತುಗಳನ್ನು ಒಪ್ಪುತ್ತೇನೆ', save: 'ಸೇವ್ ಮಾಡಿ', saved: 'ಸೇವ್ ಮಾಡಲಾಗಿದೆ!', footerText: 'ಭಾರತ ಡಿಜಿಟಲ್ ಪಬ್ಲಿಕ್ ಇನ್‌ಫ್ರಾಸ್ಟ್ರಕ್ಚರ್ • ಸುರಕ್ಷಿತ • ಖಾಸಗಿ' },
  ml: { home: 'ഹോം', myStatus: 'എന്റെ നിലവാരം', verification: 'പരിശോധന', adminServices: 'അഡ്മിൻ സേവനങ്ങൾ', settings: 'സെറ്റിംഗുകൾ', digitalIdentityServices: 'ഡിജിറ്റൽ ഐഡന്റിറ്റി സേവനങ്ങൾ', governmentOfIndia: 'ഇന്ത്യാ ഗവൺമെന്റ്', network: 'നെറ്റ്‌വർക്ക്', settingsTitle: 'സെറ്റിംഗുകൾ', networkSettings: 'നെറ്റ്‌വർക്കും സേവന വിലാസങ്ങളും', userPreferences: 'ഉപയോക്താവിന്റെ മുൻഗണനകൾ', privacySettings: 'സ്വകാര്യത ക്രമീകരണങ്ങൾ', notificationSettings: 'അറിയിപ്പ് ക്രമീകരണങ്ങൾ', liabilitySettings: 'ബാധ്യതയും നിയമപരവും', dataRetention: 'ഡാറ്റ നിലനിർത്തൽ', discuss: 'ചർച്ച ചെയ്യുക', do: 'ചെയ്യുക', pollSurvey: 'വോട്ടെടുപ്പ്/സർവേ', blog: 'ബ്ലോഗ്', talk: 'സംസാരിക്കുക', identityDistribution: 'ഐഡന്റിറ്റി വിതരണ സർവേ', aadhaarHolders: 'ആധാർ ഉടമകൾ', otherIdentityHolders: 'മറ്റ് ഐഡന്റിറ്റി ഉടമകൾ', noIdentity: 'ഐഡന്റിറ്റി രേഖകളൊന്നുമില്ല', enableNotifications: 'പുഷ് അറിയിപ്പുകൾ പ്രാപ്തമാക്കുക', dataCollection: 'വിശകലനത്തിനായി ഡാറ്റ ശേഖരണം അനുവദിക്കുക', shareWithGov: 'സർക്കാർ ഏജൻസികളുമായി ഡാറ്റ പങ്കിടുക', autoDelete: 'പരിശോധനയ്ക്ക് ശേഷം ഡാറ്റ സ്വയമേവ ഇല്ലാതാക്കുക', acceptLiability: 'ഡാറ്റ കൃത്യതയ്ക്കുള്ള ബാധ്യത ഞാൻ സ്വീകരിക്കുന്നു', agreeTerms: 'നിയമങ്ങളും വ്യവസ്ഥകളും ഞാൻ അംഗീകരിക്കുന്നു', save: 'സേവ് ചെയ്യുക', saved: 'സേവ് ചെയ്തു!', footerText: 'ഭാരത് ഡിജിറ്റൽ പബ്ലിക് ഇൻഫ്രാസ്ട്രക്ചർ • സുരക്ഷിത • സ്വകാര്യ' },
  or: { home: 'ହୋମ', myStatus: 'ମୋର ସ୍ଥିତି', verification: 'ଯାଞ୍ଚ', adminServices: 'ପ୍ରଶାସନିକ ସେବା', settings: 'ସେଟିଂସ', digitalIdentityServices: 'ଡିଜିଟାଲ ପରିଚୟ ସେବା', governmentOfIndia: 'ଭାରତ ସରକାର', network: 'ନେଟୱାର୍କ', settingsTitle: 'ସେଟିଂସ', networkSettings: 'ନେଟୱାର୍କ ଏବଂ ସେବା ଠିକଣା', userPreferences: 'ବ୍ୟବହାରକାରୀ ପସନ୍ଦ', privacySettings: 'ଗୋପନୀୟତା ସେଟିଂସ', notificationSettings: 'ବିଜ୍ଞପ୍ତି ସେଟିଂସ', liabilitySettings: 'ଦାୟିତ୍ୱ ଏବଂ ଆଇନଗତ', dataRetention: 'ତଥ୍ୟ ସଂରକ୍ଷଣ', discuss: 'ଆଲୋଚନା', do: 'କର', pollSurvey: 'ମତଦାନ/ସର୍ଭେ', blog: 'ବ୍ଲଗ', talk: 'କଥା ହୁଅ', identityDistribution: 'ପରିଚୟ ବଣ୍ଟନ ସର୍ଭେ', aadhaarHolders: 'ଆଧାର ଧାରୀ', otherIdentityHolders: 'ଅନ୍ୟ ପରିଚୟ ଧାରୀ', noIdentity: 'କୌଣସି ପରିଚୟ ଦଲିଲ ନାହିଁ', enableNotifications: 'ପୁସ ବିଜ୍ଞପ୍ତି ସକ୍ଷମ କର', dataCollection: 'ବିଶ୍ଳେଷଣ ପାଇଁ ତଥ୍ୟ ସଂଗ୍ରହକୁ ଅନୁମତି ଦିଅ', shareWithGov: 'ସରକାରୀ ଏଜେନ୍ସି ସହ ତଥ୍ୟ ସାଝା କର', autoDelete: 'ଯାଞ୍ଚ ପରେ ତଥ୍ୟକୁ ସ୍ୱୟଂଚାଳିତ ଭାବେ ବିଲୋପ କର', acceptLiability: 'ମୁଁ ତଥ୍ୟ ସଠିକତା ପାଇଁ ଦାୟିତ୍ୱ ଗ୍ରହଣ କରୁଛି', agreeTerms: 'ମୁଁ ନିୟମ ଏବଂ ସର୍ତ୍ତାବଳୀ ସହ ସହମତ', save: 'ସେଭ କର', saved: 'ସେଭ ହୋଇଛି!', footerText: 'ଭାରତ ଡିଜିଟାଲ ପବ୍ଲିକ ଇନଫ୍ରାଷ୍ଟ୍ରକଚର • ସୁରକ୍ଷିତ • ବ୍ୟକ୍ତିଗତ' },
}

interface LanguageContextType {
  language: Language
  setLanguage: (lang: Language) => void
  t: (key: string) => string
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined)

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [language, setLanguage] = useState<Language>('en')

  const t = (key: string): string => {
    return (translations[language] as any)[key] || key
  }

  return (
    <LanguageContext.Provider value={{ language, setLanguage, t }}>
      {children}
    </LanguageContext.Provider>
  )
}

export function useLanguage() {
  const context = useContext(LanguageContext)
  if (context === undefined) {
    throw new Error('useLanguage must be used within a LanguageProvider')
  }
  return context
}
