import 'package:flutter/material.dart';

import '../ui/app_shell.dart';

const _kTitleBlue = Color(0xFF1500C8);
const _kPanelBlue = Color(0xFF056FD1);
const _kAccent = Color(0xFF11B7CB);
const _kGreen = Color(0xFF34C759);

class AboutUsScreen extends StatelessWidget {
  final String userName;

  const AboutUsScreen({
    super.key,
    required this.userName,
  });

  static const _developers = [
    _Developer(
      name: 'Bungualan, Renz F.',
      role: 'System Analyst',
      imageAsset: 'assets/images/renz.jpg',
    ),
    _Developer(
      name: 'Cuentas, Jade Allen',
      role: 'System Tester',
      imageAsset: 'assets/images/jade.jpg',
    ),
    _Developer(
      name: 'De Rama, John Cedrick B.',
      role: 'Sytem Designer',
      imageAsset: 'assets/images/derama.jpg',
    ),
    _Developer(
      name: 'Ecal, Jomaica H.',
      role: 'Project Manager',
      imageAsset: 'assets/images/ecal.png',
    ),
    _Developer(
      name: 'Gucela, Diana T.',
      role: 'Technical Writer',
      imageAsset: 'assets/images/diana.jpg',
    ),
    _Developer(
      name: 'Manalo, Mary Jasmine B.',
      role: 'Programmer',
      imageAsset: 'assets/images/mary.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'About us',
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                onBack: () => Navigator.of(context).pop(),
                onMenu: () => scaffoldKey.currentState?.openEndDrawer(),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 10),
                child: Text(
                  'ABOUT US',
                  style: TextStyle(
                    color: _kTitleBlue,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        offset: Offset(3, 4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  decoration: BoxDecoration(
                    color: _kPanelBlue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color.fromARGB(255, 156, 156, 156)
                          .withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 186, 182, 182)
                            .withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                      children: const [
                        _IntroCard(),
                        SizedBox(height: 14),
                        _SectionPanel(
                          title: 'Developers',
                          child: _DeveloperGrid(developers: _developers),
                        ),
                        SizedBox(height: 14),
                        _InfoPanel(
                          icon: Icons.school_rounded,
                          title: 'Pamantasan ng Lungsod ng San Pablo (PLSP)',
                          body: 'San Pablo City, Laguna',
                        ),
                        SizedBox(height: 14),
                        _SectionPanel(
                          title: 'Contact us',
                          child: _ContactCard(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: const Column(
        children: [
          Text(
            'Team Synergy',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF071A3F),
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We are a dedicated group of Information Technology students committed to creating an accessible learning app for Sign Language. Talk with Hands helps users learn alphabets, numbers, basic words, tutorials, and practice activities through games, combine it one friendly platform.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF28435F),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionPanel({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DeveloperGrid extends StatelessWidget {
  final List<_Developer> developers;

  const _DeveloperGrid({required this.developers});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 490 ? 2 : 3;
        return GridView.builder(
          itemCount: developers.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
            mainAxisExtent: 185,
          ),
          itemBuilder: (context, index) {
            return _DeveloperTile(developer: developers[index]);
          },
        );
      },
    );
  }
}

class _DeveloperTile extends StatelessWidget {
  final _Developer developer;

  const _DeveloperTile({required this.developer});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _kAccent, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: Image.asset(
                developer.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black,
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          developer.name,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kGreen.withValues(alpha: 0.55)),
          ),
          child: Text(
            developer.role,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F6E32),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _kAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF071A3F),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF28435F),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(222, 156, 241, 244),
        borderRadius: BorderRadius.circular(42),
        border: Border.all(color: Colors.black, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Column(
        children: [
          _ContactLine(
            label: 'Email:',
            value: 'talkwithhands06@gmail.com',
          ),
          SizedBox(height: 20),
          _ContactLine(
            label: 'Contact Number:',
            value: '09560293552',
          ),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final String label;
  final String value;

  const _ContactLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF071A3F),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: const Color.fromARGB(200, 255, 255, 255).withValues(alpha: 0.96),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: const Color.fromARGB(255, 216, 215, 221),
      width: 1.4,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _Developer {
  final String name;
  final String role;
  final String imageAsset;

  const _Developer({
    required this.name,
    required this.role,
    required this.imageAsset,
  });
}