import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_bus/features/auth/domain/credentials.dart';

void main() {
  group('isCollegeStudentEmail', () {
    test('accepts the student domain in any case and with spaces around it', () {
      expect(isCollegeStudentEmail('cb.en.u4cse21001@cb.students.amrita.edu'), isTrue);
      expect(isCollegeStudentEmail('  CB.EN.U4CSE21001@CB.Students.Amrita.EDU '), isTrue);
    });

    test('rejects other domains, including look-alikes', () {
      expect(isCollegeStudentEmail('someone@gmail.com'), isFalse);
      expect(isCollegeStudentEmail('staff@cb.amrita.edu'), isFalse);
      expect(isCollegeStudentEmail('x@cb.students.amrita.edu.evil.com'), isFalse);
      expect(isCollegeStudentEmail('x@evilcb.students.amrita.edu'), isFalse);
    });

    test('rejects malformed addresses', () {
      expect(isCollegeStudentEmail(''), isFalse);
      expect(isCollegeStudentEmail('@cb.students.amrita.edu'), isFalse);
      expect(isCollegeStudentEmail('a b@cb.students.amrita.edu'), isFalse);
      expect(isCollegeStudentEmail('a@b@cb.students.amrita.edu'), isFalse);
    });
  });

  group('driver credentials', () {
    test('maps a driver ID to one email whatever the case or spacing', () {
      expect(driverEmailFor(' drv001 '), 'drv001@drivers.whereismybus.invalid');
      expect(driverEmailFor('DRV001'), driverEmailFor('drv001'));
      expect(isDriverAccountEmail(driverEmailFor('DRV001')), isTrue);
      expect(isDriverAccountEmail('drv001@cb.students.amrita.edu'), isFalse);
    });

    test('validates driver IDs', () {
      expect(isValidDriverId('DRV001'), isTrue);
      expect(isValidDriverId('drv-12'), isTrue);
      expect(isValidDriverId('D1'), isFalse);
      expect(isValidDriverId('DRV 001'), isFalse);
      expect(isValidDriverId('drv@001'), isFalse);
    });

    test('PIN must be exactly six digits', () {
      expect(isValidPin('482913'), isTrue);
      expect(isValidPin('48291'), isFalse);
      expect(isValidPin('4829134'), isFalse);
      expect(isValidPin('48291a'), isFalse);
    });
  });
}
