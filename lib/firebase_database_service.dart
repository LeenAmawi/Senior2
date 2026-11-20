
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseDatabaseService {
  static final FirebaseDatabase database =
  FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    'https://kidsentinel-dd697-default-rtdb.firebaseio.com',
  );

  static DatabaseReference childStatus(String childId) {
    return database.ref('childStatus/$childId');
  }

  // Read a child's live status
  static Future<DataSnapshot> getChildStatus(String childId) async {
    return await childStatus(childId).get();
  }
}
