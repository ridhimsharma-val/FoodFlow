import 'package:flutter_test/flutter_test.dart';
import 'package:food_flow/services/auth_service.dart';

void main() {
  test('UserProfile model parses provider and receiver correctly', () {
    final providerProfile = UserProfile(
      id: 'uuid-1234',
      email: 'chef@kitchen.org',
      role: 'provider',
      organizationName: 'Grand Palace Kitchen',
    );

    expect(providerProfile.isProvider, isTrue);
    expect(providerProfile.isReceiver, isFalse);
    expect(providerProfile.roleDisplay, 'Food Provider');

    final receiverProfile = UserProfile(
      id: 'uuid-5678',
      email: 'relief@shelter.org',
      role: 'receiver',
      organizationName: 'Hope Relief Foundation',
    );

    expect(receiverProfile.isProvider, isFalse);
    expect(receiverProfile.isReceiver, isTrue);
    expect(receiverProfile.roleDisplay, 'NGO / Receiver');
  });

  test('UserProfile fromJson correctly handles profiles row', () {
    final json = {
      'id': 'uuid-abc',
      'email': 'org@relief.org',
      'role': 'receiver',
      'full_name': 'Sarah Connor',
      'organization_name': 'Hope Center',
      'location': 'Indiranagar, Bengaluru',
    };

    final profile = UserProfile.fromJson(json);
    expect(profile.id, 'uuid-abc');
    expect(profile.email, 'org@relief.org');
    expect(profile.role, 'receiver');
    expect(profile.fullName, 'Sarah Connor');
    expect(profile.organizationName, 'Hope Center');
    expect(profile.isReceiver, isTrue);
  });

  test('UserProfile parses volunteer profile correctly', () {
    final volunteerProfile = UserProfile(
      id: 'uuid-vol-1',
      email: 'alex@foodflow.org',
      role: 'volunteer',
      fullName: 'Alex Morgan',
    );

    expect(volunteerProfile.isVolunteer, isTrue);
    expect(volunteerProfile.isProvider, isFalse);
    expect(volunteerProfile.isReceiver, isFalse);
    expect(volunteerProfile.roleDisplay, 'Rescue Volunteer');
  });
}
