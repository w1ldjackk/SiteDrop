// lib/data/models/user.g.dart
part of 'user.dart';

// Hive adapter for User
class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    return User(
      id: reader.readString(),
      name: reader.readString(),
      phone: reader.readString(),
      email: reader.readString(),
      role: reader.readString(),
      avatar: reader.readString(),
      isVerified: reader.readBool(),
      createdAt: reader.readDateTime(),
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.phone);
    writer.writeString(obj.email);
    writer.writeString(obj.role);
    writer.writeString(obj.avatar ?? '');
    writer.writeBool(obj.isVerified);
    writer.writeDateTime(obj.createdAt);
  }
}

extension on BinaryWriter {
  void writeDateTime(DateTime? createdAt) {
    if (createdAt != null) {
      writeInt(createdAt.millisecondsSinceEpoch);
    } else {
      writeInt(0); // handle null
    }
  }
}

extension on BinaryReader {
  DateTime? readDateTime() {
    final millis = readInt();
    if (millis == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
