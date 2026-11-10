import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore seed data utility for sample lessons, signs, and exercises.
class FirestoreSeed {
  static final _db = FirebaseFirestore.instance;

  /// Creates missing sample documents without replacing existing content.
  static Future<void> seedFirestoreData() async {
    await _seedSigns();
    await _seedLessons();
    await _seedGrammarExercises();
  }

  static Future<void> _seedIfMissing(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final document = _db.collection(collection).doc(documentId);
    final snapshot = await document.get();
    if (!snapshot.exists) {
      await document.set(data);
    }
  }

  static Future<void> _seedSigns() async {
    final signs = [
      {
        'word': 'Hello',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'greetings',
        'difficulty': 'beginner'
      },
      {
        'word': 'Goodbye',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'greetings',
        'difficulty': 'beginner'
      },
      {
        'word': 'Thank You',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'greetings',
        'difficulty': 'beginner'
      },
      {
        'word': 'Yes',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'basic_signs',
        'difficulty': 'beginner'
      },
      {
        'word': 'No',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'basic_signs',
        'difficulty': 'beginner'
      },
      {
        'word': 'Help',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'emergency',
        'difficulty': 'beginner'
      },
      {
        'word': 'Please',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'basic_signs',
        'difficulty': 'beginner'
      },
      {
        'word': 'Sorry',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'basic_signs',
        'difficulty': 'beginner'
      },
      {
        'word': 'Hospital',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'health',
        'difficulty': 'intermediate'
      },
      {
        'word': 'Medicine',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'health',
        'difficulty': 'intermediate'
      },
      {
        'word': 'Doctor',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'health',
        'difficulty': 'intermediate'
      },
      {
        'word': 'School',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'education',
        'difficulty': 'beginner'
      },
      {
        'word': 'Teacher',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'education',
        'difficulty': 'beginner'
      },
      {
        'word': 'Student',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'education',
        'difficulty': 'beginner'
      },
      {
        'word': 'Home',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'family',
        'difficulty': 'beginner'
      },
      {
        'word': 'Family',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'family',
        'difficulty': 'beginner'
      },
      {
        'word': 'Mother',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'family',
        'difficulty': 'beginner'
      },
      {
        'word': 'Father',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'family',
        'difficulty': 'beginner'
      },
      {
        'word': 'Brother',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'family',
        'difficulty': 'beginner'
      },
      {
        'word': 'Sister',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'family',
        'difficulty': 'beginner'
      },
      {
        'word': 'Food',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'daily_life',
        'difficulty': 'beginner'
      },
      {
        'word': 'Water',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'daily_life',
        'difficulty': 'beginner'
      },
      {
        'word': 'Eat',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'daily_life',
        'difficulty': 'beginner'
      },
      {
        'word': 'Drink',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'daily_life',
        'difficulty': 'beginner'
      },
      {
        'word': 'Bus',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'travel',
        'difficulty': 'intermediate'
      },
      {
        'word': 'Market',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'travel',
        'difficulty': 'intermediate'
      },
      {
        'word': 'Where',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'travel',
        'difficulty': 'intermediate'
      },
      {
        'word': 'Friend',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'community',
        'difficulty': 'beginner'
      },
      {
        'word': 'Need',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'community',
        'difficulty': 'intermediate'
      },
      {
        'word': 'Work',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'gifUrl': 'https://media.giphy.com/media/g9GgY0nv8CKUg/giphy.gif',
        'category': 'community',
        'difficulty': 'intermediate'
      },
    ];

    const signIds = [
      'hello',
      'goodbye',
      'thank_you',
      'yes',
      'no',
      'help',
      'please',
      'sorry',
      'hospital',
      'medicine',
      'doctor',
      'school',
      'teacher',
      'student',
      'home',
      'family',
      'mother',
      'father',
      'brother',
      'sister',
      'food',
      'water',
      'eat',
      'drink',
      'bus',
      'market',
      'where',
      'friend',
      'need',
      'work'
    ];

    for (int i = 0; i < signs.length; i++) {
      await _seedIfMissing('signs', signIds[i], signs[i]);
    }
  }

  static Future<void> _seedLessons() async {
    final lessons = [
      {
        'title': 'Greetings 101',
        'category': 'greetings',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'description':
            'Learn the basics of greeting someone in Filipino Sign Language. Master Hello, Goodbye, and common courtesies.',
        'signIds': ['hello', 'goodbye', 'thank_you', 'please']
      },
      {
        'title': 'Basic Signs',
        'category': 'basic_signs',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'description':
            'Essential signs everyone should know: Yes, No, Please, and Sorry. Perfect for beginners.',
        'signIds': ['yes', 'no', 'please', 'sorry']
      },
      {
        'title': 'Emergency Phrases',
        'category': 'emergency',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'description':
            'Important signs for emergency situations. Learn how to call for help and communicate urgently.',
        'signIds': ['help', 'hospital', 'medicine', 'doctor']
      },
      {
        'title': 'School Day',
        'category': 'education',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'description':
            'Useful school phrases for students, teachers, and classroom conversations.',
        'signIds': ['school', 'teacher', 'student', 'please']
      },
      {
        'title': 'Family & Home',
        'category': 'family',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'description':
            'Talk about your family, your home, and the people you love in everyday conversation.',
        'signIds': ['family', 'mother', 'father', 'home', 'brother', 'sister']
      },
      {
        'title': 'Daily Routine',
        'category': 'daily_life',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'description':
            'Learn everyday routines like eating, drinking, and basic needs for daily life.',
        'signIds': ['food', 'water', 'eat', 'drink', 'need']
      },
      {
        'title': 'Travel Basics',
        'category': 'travel',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'description':
            'Useful phrases for travel, directions, and navigating a public place confidently.',
        'signIds': ['where', 'bus', 'market', 'school']
      },
      {
        'title': 'Community & Friends',
        'category': 'community',
        'videoUrl':
            'https://res.cloudinary.com/demo/video/upload/elephants.mp4',
        'description':
            'Practice talking with friends, coworkers, and neighbors using natural everyday phrases.',
        'signIds': ['friend', 'work', 'help', 'need']
      },
      {
        'title': 'Polite Conversation',
        'category': 'greetings',
        'videoUrl': '',
        'description':
            'Review common greetings and courteous expressions for everyday conversations.',
        'signIds': ['hello', 'thank_you', 'please', 'sorry']
      },
      {
        'title': 'At the Clinic',
        'category': 'health',
        'videoUrl': '',
        'description':
            'Review health-related vocabulary for communicating about care and assistance.',
        'signIds': ['help', 'doctor', 'hospital', 'medicine']
      },
      {
        'title': 'Food and Drinks',
        'category': 'daily_life',
        'videoUrl': '',
        'description': 'Practice vocabulary for meals, eating, and drinking.',
        'signIds': ['food', 'eat', 'drink', 'water']
      },
      {
        'title': 'Getting Around',
        'category': 'travel',
        'videoUrl': '',
        'description':
            'Practice words used when asking about places and getting around.',
        'signIds': ['where', 'bus', 'market', 'need']
      },
      {
        'title': 'Classroom Review',
        'category': 'education',
        'videoUrl': '',
        'description':
            'Review school, teacher, and student vocabulary in a classroom context.',
        'signIds': ['school', 'teacher', 'student', 'please']
      },
      {
        'title': 'People and Work',
        'category': 'community',
        'videoUrl': '',
        'description':
            'Practice vocabulary for people and common community settings.',
        'signIds': ['friend', 'work', 'family', 'home']
      },
    ];

    const lessonIds = [
      'lesson_greetings',
      'lesson_basics',
      'lesson_emergency',
      'lesson_school',
      'lesson_family',
      'lesson_daily_routine',
      'lesson_travel',
      'lesson_community',
      'lesson_polite_conversation',
      'lesson_clinic',
      'lesson_food_drinks',
      'lesson_getting_around',
      'lesson_classroom_review',
      'lesson_people_work',
    ];

    for (int i = 0; i < lessons.length; i++) {
      await _seedIfMissing('lessons', lessonIds[i], lessons[i]);
    }
  }

  static Future<void> _seedGrammarExercises() async {
    final exercises = [
      {
        'category': 'emergency',
        'difficulty': 'beginner',
        'promptText': 'I need help at the hospital.',
        'lessonId': 'lesson_emergency',
        'tiles': [
          {'signId': 'need', 'correctPosition': 1},
          {'signId': 'help', 'correctPosition': 2},
          {'signId': 'hospital', 'correctPosition': 3},
        ]
      },
      {
        'category': 'family',
        'difficulty': 'beginner',
        'promptText': 'My mother and father are home.',
        'lessonId': 'lesson_family',
        'tiles': [
          {'signId': 'mother', 'correctPosition': 1},
          {'signId': 'father', 'correctPosition': 2},
          {'signId': 'home', 'correctPosition': 3},
        ]
      },
      {
        'category': 'education',
        'difficulty': 'beginner',
        'promptText': 'The teacher is in school.',
        'lessonId': 'lesson_school',
        'tiles': [
          {'signId': 'teacher', 'correctPosition': 1},
          {'signId': 'school', 'correctPosition': 2},
          {'signId': 'student', 'correctPosition': 3},
        ]
      },
      {
        'category': 'daily_life',
        'difficulty': 'intermediate',
        'promptText': 'I want food and water.',
        'lessonId': 'lesson_daily_routine',
        'tiles': [
          {'signId': 'food', 'correctPosition': 1},
          {'signId': 'water', 'correctPosition': 2},
          {'signId': 'need', 'correctPosition': 3},
        ]
      },
      {
        'category': 'travel',
        'difficulty': 'intermediate',
        'promptText': 'Where is the bus stop?',
        'lessonId': 'lesson_travel',
        'tiles': [
          {'signId': 'where', 'correctPosition': 1},
          {'signId': 'bus', 'correctPosition': 2},
          {'signId': 'market', 'correctPosition': 3},
        ]
      },
      {
        'category': 'community',
        'difficulty': 'intermediate',
        'promptText': 'A friend can help at work.',
        'lessonId': 'lesson_community',
        'tiles': [
          {'signId': 'friend', 'correctPosition': 1},
          {'signId': 'help', 'correctPosition': 2},
          {'signId': 'work', 'correctPosition': 3},
        ]
      },
      {
        'category': 'greetings',
        'difficulty': 'beginner',
        'promptText': 'Hello. Thank you. Goodbye.',
        'lessonId': 'lesson_polite_conversation',
        'tiles': [
          {'signId': 'hello', 'correctPosition': 1},
          {'signId': 'thank_you', 'correctPosition': 2},
          {'signId': 'goodbye', 'correctPosition': 3},
        ]
      },
      {
        'category': 'health',
        'difficulty': 'beginner',
        'promptText': 'The doctor is at the hospital. I need medicine.',
        'lessonId': 'lesson_clinic',
        'tiles': [
          {'signId': 'help', 'correctPosition': 1},
          {'signId': 'doctor', 'correctPosition': 2},
          {'signId': 'hospital', 'correctPosition': 3},
        ]
      },
      {
        'category': 'daily_life',
        'difficulty': 'beginner',
        'promptText': 'Eat food. Drink water.',
        'lessonId': 'lesson_food_drinks',
        'tiles': [
          {'signId': 'food', 'correctPosition': 1},
          {'signId': 'eat', 'correctPosition': 2},
          {'signId': 'drink', 'correctPosition': 3},
          {'signId': 'water', 'correctPosition': 4},
        ]
      },
      {
        'category': 'travel',
        'difficulty': 'intermediate',
        'promptText': 'Where is the bus to the market?',
        'lessonId': 'lesson_getting_around',
        'tiles': [
          {'signId': 'where', 'correctPosition': 1},
          {'signId': 'bus', 'correctPosition': 2},
          {'signId': 'market', 'correctPosition': 3},
        ]
      },
      {
        'category': 'education',
        'difficulty': 'beginner',
        'promptText': 'The student and teacher are at school.',
        'lessonId': 'lesson_classroom_review',
        'tiles': [
          {'signId': 'student', 'correctPosition': 1},
          {'signId': 'teacher', 'correctPosition': 2},
          {'signId': 'school', 'correctPosition': 3},
        ]
      },
      {
        'category': 'community',
        'difficulty': 'intermediate',
        'promptText': 'My friend and family are at home and work.',
        'lessonId': 'lesson_people_work',
        'tiles': [
          {'signId': 'friend', 'correctPosition': 1},
          {'signId': 'family', 'correctPosition': 2},
          {'signId': 'home', 'correctPosition': 3},
          {'signId': 'work', 'correctPosition': 4},
        ]
      },
    ];

    const exerciseIds = [
      'grammar_hospital_help',
      'grammar_family_intro',
      'grammar_school_day',
      'grammar_daily_routine',
      'grammar_travel_basics',
      'grammar_community_help',
      'grammar_polite_conversation',
      'grammar_clinic_visit',
      'grammar_food_drinks',
      'grammar_getting_around',
      'grammar_classroom_review',
      'grammar_people_work',
    ];

    for (int i = 0; i < exercises.length; i++) {
      await _seedIfMissing('grammarExercises', exerciseIds[i], exercises[i]);
    }
  }
}
