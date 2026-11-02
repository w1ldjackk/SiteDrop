// Widget tests for shared presentation widgets in sitedrop_core.
// CI-safe: no backend required.

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sitedrop_core/presentation/theme/auth_theme.dart';
import 'package:sitedrop_core/presentation/widgets/cards/order_status_chip.dart';
import 'package:sitedrop_core/presentation/widgets/forms/custom_dropdown.dart';
import 'package:sitedrop_core/presentation/widgets/forms/custom_text_field.dart';
import 'package:sitedrop_core/presentation/widgets/forms/otp_pin_fields.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/primary_button.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/secondary_button.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/social_button.dart';
import 'package:sitedrop_core/data/models/order.dart';

Widget _testWidget(Widget child) => MaterialApp(
      home: Scaffold(
        body: SafeArea(child: child),
      ),
    );

void main() {
  group('PrimaryButton', () {
    testWidgets('renders FilledButton with text', (tester) async {
      await tester.pumpWidget(_testWidget(
        PrimaryButton(onPressed: () {}, text: 'Save'),
      ));
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    test('is disabled when onPressed is null', () {
      final widget = PrimaryButton(onPressed: null, text: 'Save');
      expect(widget.onPressed, isNull);
    });

    test('isLoading defaults to false', () {
      final widget = PrimaryButton(onPressed: () {}, text: 'Save');
      expect(widget.isLoading, isFalse);
    });
  });

  group('SecondaryButton', () {
    testWidgets('renders OutlinedButton with text', (tester) async {
      await tester.pumpWidget(_testWidget(
        SecondaryButton(onPressed: () {}, text: 'Cancel'),
      ));
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    test('is disabled when onPressed is null', () {
      final widget = SecondaryButton(onPressed: null, text: 'Cancel');
      expect(widget.onPressed, isNull);
    });
  });

  group('SocialButton', () {
    testWidgets('renders OutlinedButton.icon', (tester) async {
      await tester.pumpWidget(_testWidget(
        SocialButton(
          onPressed: () {},
          text: 'Google',
          icon: FontAwesomeIcons.google,
        ),
      ));
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
    });

    test('google factory creates button with Google text', () {
      final widget = SocialButton.google(onPressed: () {});
      expect(widget.text, 'Google');
      expect(widget.icon, FontAwesomeIcons.google);
    });

    test('apple factory creates button with Apple text', () {
      final widget = SocialButton.apple(onPressed: () {});
      expect(widget.text, 'Apple');
      expect(widget.icon, FontAwesomeIcons.apple);
    });
  });

  group('CustomTextField', () {
    testWidgets('renders TextFormField with label and hint', (tester) async {
      await tester.pumpWidget(_testWidget(
        CustomTextField(
          label: 'Email',
          hint: 'Enter your email',
        ),
      ));
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
    });

    test('obscureText defaults to false', () {
      final widget = CustomTextField(label: 'Password');
      expect(widget.obscureText, isFalse);
    });

    test('obscureText is configurable', () {
      final widget = CustomTextField(label: 'Password', obscureText: true);
      expect(widget.obscureText, isTrue);
    });
  });

  group('CustomDropdown', () {
    testWidgets('renders DropdownButtonFormField with items', (tester) async {
      await tester.pumpWidget(_testWidget(
        CustomDropdown<String>(
          items: [
            {'value': 'a', 'label': 'Option A'},
            {'value': 'b', 'label': 'Option B'},
          ],
          hint: 'Select an option',
          onChanged: (value) {},
        ),
      ));
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    test('items is required', () {
      final widget = CustomDropdown<String>(
        items: [{'value': 'a', 'label': 'A'}],
        onChanged: (v) {},
      );
      expect(widget.items, hasLength(1));
    });
  });

  group('OtpPinFields', () {
    test('creates specified number of controllers', () {
      final controllers = List.generate(6, (_) => TextEditingController());

      final widget = OtpPinFields(
        controllers: controllers,
        onCompleted: (code) {},
      );

      expect(widget.length, 6);
      expect(widget.controllers, hasLength(6));
    });

    test('onCompleted callback is optional', () {
      final controllers = List.generate(4, (_) => TextEditingController());

      final widget = OtpPinFields(
        controllers: controllers,
        length: 4,
      );

      expect(widget.length, 4);
      expect(widget.onCompleted, isNull);
    });
  });

  group('OrderStatusChip', () {
    testWidgets('renders pending status chip', (tester) async {
      await tester.pumpWidget(_testWidget(
        OrderStatusChip(status: OrderStatus.pending),
      ));
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('renders delivered status chip', (tester) async {
      await tester.pumpWidget(_testWidget(
        OrderStatusChip(status: OrderStatus.delivered),
      ));
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('renders cancelled status chip', (tester) async {
      await tester.pumpWidget(_testWidget(
        OrderStatusChip(status: OrderStatus.cancelled),
      ));
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });
  });

  group('AuthTheme', () {
    testWidgets('title returns styled text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final style = AuthTheme.title(context, size: 24);
              expect(style.fontSize, 24);
              expect(style.fontWeight, FontWeight.w700);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('subtitle returns styled text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final style = AuthTheme.subtitle(context);
              expect(style.fontSize, 16);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('field returns InputDecoration with hint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final decoration = AuthTheme.field(
                context,
                hint: 'Enter email',
                icon: Icons.email,
              );
              expect(decoration.hintText, 'Enter email');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}