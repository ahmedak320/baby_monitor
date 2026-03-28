/// Privacy policy and terms of service text content.
/// COPPA-compliant privacy policy for a children's content app.
class LegalContent {
  LegalContent._();

  static const String privacyPolicyLastUpdated = '2026-03-24';
  static const String termsLastUpdated = '2026-03-24';

  static const String privacyPolicy =
      '''
PRIVACY POLICY

Last Updated: $privacyPolicyLastUpdated

Baby Monitor ("we", "us", "our") is committed to protecting the privacy of children and families. This Privacy Policy explains how we collect, use, and protect information when you use our app.

COPPA COMPLIANCE

Baby Monitor complies with the Children's Online Privacy Protection Act (COPPA). We do not collect personal information directly from children. All accounts are created and managed by parents or legal guardians.

INFORMATION WE COLLECT

Parent Account Information:
- Email address (for account creation and login)
- Display name
- Device identifiers (for multi-device sync)

Child Profile Information (created by parents only):
- Child's first name
- Date of birth (used to calculate age for content filtering)
- Content preferences and filter settings

Usage Data:
- Watch history (which videos were viewed, per child profile)
- Screen time data (session duration per child)
- Content filtering logs (which videos were blocked and why)

We do NOT collect:
- Location data
- Photos or videos from the device
- Contact lists
- Personal information directly from children
- Voice data or recordings

HOW WE USE INFORMATION

- To provide age-appropriate content filtering
- To enforce screen time limits set by parents
- To generate activity reports for parents
- To improve our AI content analysis through community-shared video analysis results (never personal data)
- To manage subscriptions and billing

COMMUNITY-SHARED DATA

Video analysis results (safety scores, content labels) are shared across all users to reduce analysis costs. This data is about YouTube videos, not about your children. No personal or identifiable information is included in shared analyses.

DATA STORAGE AND SECURITY

- Data is stored in Supabase (hosted on AWS, SOC 2 compliant)
- All data is encrypted in transit (TLS) and at rest
- Row-level security ensures parents can only access their own data
- We do not sell personal information to third parties

DATA RETENTION AND DELETION

- You can delete your account at any time from the app settings
- Account deletion removes all associated data, including child profiles, watch history, and preferences (cascade delete)
- Video analysis results contributed to the community cache are anonymized and retained

THIRD-PARTY SERVICES

- Supabase (database and authentication)
- YouTube Data API (video metadata, subject to Google's Privacy Policy)
- Anthropic Claude API (AI content analysis, no personal data sent)
- RevenueCat (subscription management)

CHANGES TO THIS POLICY

We will notify users of material changes via in-app notification. Continued use after changes constitutes acceptance.

CONTACT US

For privacy questions or data deletion requests:
Email: support@babymonitor.app
''';

  static const String termsOfService =
      '''
TERMS OF SERVICE

Last Updated: $termsLastUpdated

By using Baby Monitor ("the App"), you agree to these Terms of Service.

1. ELIGIBILITY

You must be 18 years or older (or the age of majority in your jurisdiction) to create an account. The App is designed for parents and legal guardians to manage their children's YouTube viewing.

2. ACCOUNT RESPONSIBILITIES

- You are responsible for maintaining the security of your account
- You are responsible for all activity under your account
- You must provide accurate information when creating child profiles
- You must not share your account credentials

3. CONTENT FILTERING DISCLAIMER

Baby Monitor uses AI to analyze YouTube content for safety. While we strive for accuracy:
- No content filtering system is 100% accurate
- AI analysis may miss inappropriate content or incorrectly flag safe content
- Parents should review filtered content decisions and adjust settings as needed
- Baby Monitor is a tool to assist parents, not a replacement for parental supervision

4. YOUTUBE CONTENT

- Baby Monitor does not host or store YouTube videos
- Videos are played through YouTube's embedded player
- YouTube's Terms of Service apply to all video content
- We are not responsible for content available on YouTube

5. SUBSCRIPTION AND BILLING

- Free tier includes 50 video analyses per month
- Premium subscription is billed monthly at the listed price
- Subscriptions auto-renew unless cancelled
- Refunds are handled through the respective app store

6. COMMUNITY FEATURES

- Users may rate the accuracy of video analyses
- Community ratings help improve analysis quality for all users
- Abuse of the rating system (spam, deliberate misinformation) may result in account suspension

7. ACCEPTABLE USE

You may not:
- Attempt to circumvent content filtering for malicious purposes
- Use the App to collect data about other users
- Reverse-engineer the App or its AI analysis pipeline
- Use the App for any illegal purpose

8. LIMITATION OF LIABILITY

Baby Monitor is provided "as is". We are not liable for:
- Content that bypasses our filtering system
- Decisions made based on our content analysis
- Service interruptions or data loss
- Third-party service outages (YouTube, Supabase)

9. TERMINATION

We reserve the right to suspend or terminate accounts that violate these terms. You may delete your account at any time.

10. CHANGES TO TERMS

We may update these terms. Material changes will be communicated via in-app notification. Continued use constitutes acceptance.

11. GOVERNING LAW

These terms are governed by the laws of the jurisdiction in which the App operator is established.

CONTACT US

For questions about these terms:
Email: support@babymonitor.app
''';
}
