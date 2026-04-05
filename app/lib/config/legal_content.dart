/// Privacy policy, terms of service, and all legal documents.
/// COPPA-compliant, GDPR-aware, CCPA-aware legal content for a children's
/// content filtering app published on Google Play and Apple App Store.
class LegalContent {
  LegalContent._();

  static const String currentVersion = '2026-04-05-v1';
  static const String privacyPolicyLastUpdated = '2026-04-05';
  static const String termsLastUpdated = '2026-04-05';

  // ---------------------------------------------------------------------------
  // 1. PRIVACY POLICY
  // ---------------------------------------------------------------------------
  static const String privacyPolicy =
      '''
PRIVACY POLICY

Last Updated: $privacyPolicyLastUpdated

Baby Monitor ("we," "us," "our," or "the Company") operates the Baby Monitor mobile application (the "App"). This Privacy Policy explains how we collect, use, disclose, and safeguard your information and the information of children whose profiles you create when you use the App.

By creating an account or using the App, you consent to the practices described in this Privacy Policy.

1. WHO WE ARE

Baby Monitor is operated by Baby Monitor App.
Email: support@babymonitor.app

For privacy inquiries, contact our Data Protection Officer at: privacy@babymonitor.app

2. SCOPE

This Privacy Policy applies to the Baby Monitor mobile application available on iOS (Apple App Store) and Android (Google Play Store). It covers information collected from parent/guardian users ("Parents") and information Parents provide about their children ("Children").

3. INFORMATION WE COLLECT

3.1 Parent Account Information
When you create an account, we collect:
- Email address (required for account creation and login)
- Display name (shown in the app)
- Authentication credentials (password stored as a secure hash; we never store plaintext passwords)
- Device identifiers (a unique ID generated per device installation for multi-device sync)
- Device platform (iOS or Android)

3.2 Child Profile Information (Provided by Parents Only)
When you create a child profile, we collect:
- Child's first name
- Date of birth (used solely to calculate age for content filtering; we store the date to recalculate as the child ages)
- Avatar selection (a chosen icon; no photographs are collected)
- Content filter sensitivity settings (numerical preferences for safety dimensions)
- Content type preferences (preferred, allowed, or blocked content categories)

3.3 Usage Data
As the App is used, we collect:
- Watch history: which YouTube video IDs were viewed, timestamps, duration watched, and completion status (per child profile)
- Screen time sessions: session start and end times, duration, and device ID (per child profile)
- Content filtering logs: which video IDs were blocked by the filter and the specific reasons for blocking
- Content schedule configurations (premium feature)

3.4 Community and Feedback Data
- Community ratings: if you rate the accuracy of a video's safety analysis, your rating (accurate, too strict, too lenient, or dangerous) and optional comment are stored and associated with your parent account
- Beta feedback: if you submit feedback, we collect your message, feedback category, app version, and basic device information

3.5 Analytics Data
We collect anonymized usage analytics to improve the App:
- Screen views, feature usage events, and error reports
- Child identifiers in analytics are irreversibly hashed (SHA-256) before storage; we cannot recover the original identifier from the hash
- You may opt out of analytics collection at any time in the App's settings

3.6 Subscription and Payment Data
- Subscription tier (free or premium) and usage counters
- Payment transactions are processed entirely by the Apple App Store or Google Play Store; we do not collect or store credit card numbers, billing addresses, or other payment instrument details

3.7 Information We Do NOT Collect
- Location data (GPS or network-based)
- Photos, videos, or audio from your device's camera or microphone
- Contact lists or address books
- Biometric templates (Face ID/Touch ID data remains in the device's secure enclave and is never transmitted to us)
- Personal information directly from children (all data is entered by Parents)
- Advertising identifiers

4. HOW WE USE YOUR INFORMATION

We use the information we collect to:
- Provide age-appropriate content filtering based on your child's age and your filter settings
- Enforce screen time limits, break schedules, and bedtime rules you configure
- Generate activity reports visible only to you in the parent dashboard
- Improve content analysis accuracy through community-shared video safety scores (which contain no personal information about your children)
- Manage your subscription and feature access
- Respond to your feedback and support requests
- Improve app stability and fix bugs (via anonymized analytics, if you have opted in)
- Comply with legal obligations

5. HOW WE SHARE YOUR INFORMATION

5.1 Community-Shared Video Analysis Data
Video safety analysis results (safety scores, content labels, age recommendations) are shared across all App users. This data describes YouTube video content, not your children. No personally identifiable information about you or your children is included in shared analysis results.

5.2 Third-Party Service Providers
We use the following third-party services to operate the App:

Supabase (database and authentication): Stores all app data. Hosted on Amazon Web Services (AWS) in the United States. SOC 2 Type II compliant. Data encrypted in transit (TLS 1.2+) and at rest (AES-256).

YouTube Data API v3 (Google): We send search queries and video IDs to retrieve video metadata (titles, descriptions, thumbnails). No personal information about you or your children is sent. Subject to Google's Privacy Policy (https://policies.google.com/privacy).

Piped API (open-source YouTube alternative): Used as a fallback when the YouTube API quota is exhausted. We send search queries and video IDs. Piped instances are community-operated; they do not receive any personal information but may not provide the same privacy guarantees as commercial services. You may disable Piped usage in your settings if available.

Anthropic Claude API (AI content analysis): We send video metadata (title, description, tags, duration) and video transcripts to Anthropic's AI service for safety analysis. No personal information about you or your children is ever sent. Subject to Anthropic's Privacy Policy (https://www.anthropic.com/privacy).

Google Gemini API (alternative AI analysis): Same data as Claude, when configured as the active AI provider. Subject to Google's Privacy Policy.

OpenAI API (alternative AI analysis): Same data as Claude, when configured as the active AI provider. Subject to OpenAI's Privacy Policy (https://openai.com/privacy).

RevenueCat (subscription management): Receives device identifiers and subscription status for managing in-app purchases. Does not receive any child data. Subject to RevenueCat's Privacy Policy (https://www.revenuecat.com/privacy).

Local AI Models (Whisper, Detoxify, HateSonar): These models run entirely on our analysis server. Video content processed by these models is not transmitted to any third party.

5.3 We Do NOT:
- Sell your personal information or your children's personal information to anyone
- Share personal information with advertisers
- Use personal information for targeted advertising
- Share your children's personal information with third parties (only video metadata, never child data, is sent to AI providers)

6. COMMUNITY RATINGS

When you submit a community rating on a video's safety analysis, your rating is associated with your parent account internally and contributes to an aggregated community consensus score visible to all users. Other users do not see your individual identity in connection with your rating. We retain ratings to improve filtering accuracy for all families.

7. DATA RETENTION

- Watch history, content filtering logs, and screen time sessions: Automatically deleted after one (1) year
- Account data (email, display name, child profiles): Retained until you delete your account
- Community ratings: Anonymized and retained after account deletion to preserve community filtering accuracy
- Video analysis results: Retained indefinitely as they contain no personal information and benefit all users
- Analytics events: Retained for one (1) year, then deleted
- Consent records: Retained for the duration of your account plus seven (7) years for legal compliance

8. YOUR RIGHTS

Depending on your jurisdiction, you may have the following rights:

- Access: View all data we hold about you and your children (available in the App's parent dashboard and account settings)
- Deletion: Delete your account and all associated data, including all child profiles, watch history, screen time data, and preferences. Use "Delete Account" in Account Settings, or email us
- Rectification: Edit your child's profile information at any time
- Data Portability: Request a copy of your data in a machine-readable format by emailing us
- Restriction: Request that we limit processing of your data
- Objection: Object to processing based on legitimate interests
- Withdraw Consent: Withdraw consent for analytics at any time via the App's settings; withdraw consent for child data collection by deleting the child's profile
- Complaint: Lodge a complaint with your local data protection authority

To exercise any of these rights, email privacy@babymonitor.app. We will respond within thirty (30) days (GDPR) or forty-five (45) days (CCPA/CPRA).

9. INTERNATIONAL DATA TRANSFERS

Your data is processed and stored in the United States. If you are located outside the United States, including in the European Economic Area (EEA), United Kingdom (UK), or Switzerland, your data is transferred to the US. We rely on Standard Contractual Clauses (SCCs) approved by the European Commission and the UK Information Commissioner's Office to provide adequate protection for these transfers.

10. CHILDREN'S PRIVACY (COPPA COMPLIANCE)

Baby Monitor complies with the Children's Online Privacy Protection Act (COPPA) and its amended rules.

- We do not collect personal information directly from children under 13
- All accounts are created and managed by parents or legal guardians
- Parents provide verifiable consent before any child profile data is collected (see our Children's Privacy Notice for details)
- Parents may review, delete, or refuse further collection of their child's information at any time
- We do not condition a child's access to the App on disclosure of more information than is reasonably necessary

For complete details, see our separate Children's Privacy Notice.

11. SECURITY

We implement commercially reasonable administrative, technical, and physical safeguards:
- All data encrypted in transit (TLS 1.2+) and at rest (AES-256)
- Row-level security policies ensure parents can only access their own data
- Parent PINs are hashed using PBKDF2-HMAC-SHA256 with 100,000 iterations and unique salts
- API endpoints are rate-limited to prevent abuse
- Input validation on all user-submitted data
- Biometric data (Face ID, fingerprint) is processed by the device's secure enclave and never transmitted to our servers
- Worker server processes video content in temporary directories with restricted permissions, deleted immediately after analysis

No system is 100% secure. We cannot guarantee absolute security of your data.

12. CHANGES TO THIS PRIVACY POLICY

We will notify you of material changes via in-app notification and, where we have your email, by email, at least thirty (30) days before the changes take effect. If a change materially affects how we handle children's information, we will obtain renewed parental consent before applying the change.

Continued use of the App after the effective date of changes constitutes your acceptance of the revised Privacy Policy.

13. CONTACT US

For privacy questions, data requests, or concerns:
Email: privacy@babymonitor.app
Support: support@babymonitor.app
''';

  // ---------------------------------------------------------------------------
  // 2. TERMS OF SERVICE / EULA
  // ---------------------------------------------------------------------------
  static const String termsOfService =
      '''
TERMS OF SERVICE AND END USER LICENSE AGREEMENT (EULA)

Last Updated: $termsLastUpdated

Please read these Terms of Service and End User License Agreement ("Terms") carefully before using the Baby Monitor mobile application ("the App"). By creating an account or using the App, you agree to be bound by these Terms.

1. ACCEPTANCE OF TERMS

By creating an account, downloading, or using the App, you acknowledge that you have read, understood, and agree to be bound by these Terms and our Privacy Policy. If you do not agree, do not use the App.

2. ELIGIBILITY

You must be at least eighteen (18) years of age or the age of majority in your jurisdiction, whichever is greater, to create an account. By creating an account, you represent and warrant that:
(a) You meet the minimum age requirement;
(b) You are the parent or legal guardian of any child whose profile you create in the App;
(c) You have the legal authority to consent to the collection and use of your child's information as described in our Privacy Policy and Children's Privacy Notice.

3. ACCOUNT REGISTRATION AND SECURITY

3.1 You must provide accurate and complete information when creating your account.
3.2 You are solely responsible for maintaining the confidentiality of your account credentials, PIN, and biometric access.
3.3 You are responsible for all activity that occurs under your account.
3.4 You must notify us immediately at support@babymonitor.app if you become aware of any unauthorized use of your account.
3.5 We reserve the right to suspend or terminate accounts with false or misleading information.

4. CHILD PROFILES

4.1 By creating a child profile, you represent that you are the legal parent or guardian of the child and that you have provided verifiable parental consent as required by applicable law, including COPPA.
4.2 You consent to the collection and use of your child's information as described in our Privacy Policy and Children's Privacy Notice.
4.3 You are responsible for the accuracy of information in your child's profile.
4.4 You are responsible for configuring content filter settings appropriate for your child. Default settings are designed to be conservative, but you should review and adjust them based on your child's needs and maturity.

5. AI CONTENT FILTERING DISCLAIMER

THIS IS THE MOST IMPORTANT SECTION OF THESE TERMS. PLEASE READ IT CAREFULLY.

5.1 Baby Monitor uses artificial intelligence ("AI") to analyze YouTube video content for safety across multiple dimensions including overstimulation, scariness, language appropriateness, violence, educational value, and more. THIS IS AN ASSISTIVE TOOL DESIGNED TO HELP PARENTS, NOT A GUARANTEE OF CONTENT SAFETY.

5.2 AI ANALYSIS IS PROBABILISTIC AND IMPERFECT. You acknowledge and agree that:
(a) No automated content filtering system is or can be 100% accurate;
(b) The AI may fail to identify inappropriate, harmful, disturbing, or dangerous content in a video (false negatives);
(c) The AI may incorrectly flag safe and appropriate content as inappropriate (false positives);
(d) The AI may misclassify the severity, nature, or type of content;
(e) Analysis accuracy varies depending on video language, cultural context, content type, production quality, and other factors;
(f) New types of harmful content, obfuscation techniques, or evasion methods may bypass detection;
(g) AI models are updated periodically, and analysis results for the same video may change over time.

5.3 BABY MONITOR SUPPLEMENTS, BUT DOES NOT REPLACE, ACTIVE PARENTAL SUPERVISION. You agree that:
(a) You are solely responsible for supervising your children's media consumption;
(b) You will periodically review the content your child is watching and the filter decisions the App has made;
(c) You will use the manual approval and blocking features to override AI decisions when necessary;
(d) You will not rely exclusively on the App to protect your children from inappropriate content.

5.4 We make no representations or warranties regarding the accuracy, reliability, completeness, or timeliness of any content analysis, safety score, or age recommendation generated by the App.

6. YOUTUBE CONTENT

6.1 Baby Monitor does not host, store, or redistribute YouTube video content. Videos are played through YouTube's official embedded player.
6.2 YouTube's Terms of Service (https://www.youtube.com/t/terms) apply to all video content viewed through the App.
6.3 We are not responsible for the content, availability, or removal of any video on YouTube.
6.4 We use the Piped API, an open-source community-maintained YouTube frontend, as a fallback service for retrieving video metadata when the official YouTube API quota is exhausted. Piped is not affiliated with YouTube or Google.

7. SUBSCRIPTION AND BILLING

7.1 The App offers a free tier (50 video analyses per month, 1 child profile, basic screen time limits) and a premium subscription.
7.2 Premium subscription is billed at the price displayed at the time of purchase (currently \$4.99/month USD).
7.3 A seven (7) day free trial may be offered for new subscribers. If you do not cancel before the trial ends, your subscription will automatically convert to a paid subscription.
7.4 AUTOMATIC RENEWAL: Your subscription will automatically renew at the end of each billing period unless you cancel at least twenty-four (24) hours before the end of the current period.
7.5 Payment will be charged to your Apple ID account or Google Play account at confirmation of purchase.
7.6 Your account will be charged for renewal within twenty-four (24) hours prior to the end of the current billing period.

7.7 HOW TO CANCEL:
- On iPhone/iPad: Go to Settings > [Your Name] > Subscriptions > Baby Monitor > Cancel Subscription
- On Android: Go to Google Play Store > Menu > Subscriptions > Baby Monitor > Cancel

7.8 Refunds are handled by the respective app store according to their refund policies.
7.9 We reserve the right to change subscription pricing with at least thirty (30) days' notice. Price changes will take effect at the start of your next billing period after the notice period.

8. COMMUNITY FEATURES

8.1 You may voluntarily rate the accuracy of video safety analyses. Ratings contribute to an aggregated community consensus that helps improve filtering for all users.
8.2 You are responsible for the accuracy and honesty of your ratings.
8.3 You must not submit fraudulent, abusive, misleading, or spam ratings.
8.4 We reserve the right to moderate, remove, or adjust the weight of any community rating.
8.5 Neither we nor any user shall be liable for defamation in connection with an honest rating of a video's safety analysis accuracy.
8.6 We are not liable for filtering decisions that other users make based on community ratings.

9. INTELLECTUAL PROPERTY

9.1 The App and all of its content, features, and functionality (excluding YouTube content), including but not limited to software, code, AI models, design, text, graphics, and logos, are owned by the Company and are protected by copyright, trademark, and other intellectual property laws.
9.2 AI-generated safety scores, content labels, and analysis results are the property of the Company.
9.3 By submitting community ratings or feedback, you grant us a worldwide, royalty-free, non-exclusive, perpetual, irrevocable license to use, reproduce, modify, and distribute your submissions in connection with operating and improving the App.
9.4 You retain ownership of any personal information you provide.

10. ACCEPTABLE USE

You agree not to:
(a) Attempt to circumvent, disable, or interfere with content filtering or parental gate mechanisms;
(b) Reverse-engineer, decompile, or disassemble the App or its AI analysis pipeline;
(c) Use automated means (bots, scrapers) to access the App or its data;
(d) Use the App to collect data about other users;
(e) Submit false or misleading community ratings or feedback;
(f) Share your account credentials with others;
(g) Impersonate another person or entity;
(h) Use the App for any illegal purpose;
(i) Interfere with or disrupt the operation of the App or its servers;
(j) Provide access to the App to children without appropriate parental supervision and configured safety settings.

11. DISCLAIMER OF WARRANTIES

THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.

WITHOUT LIMITING THE FOREGOING, WE DO NOT WARRANT THAT:
(a) THE APP WILL MEET YOUR REQUIREMENTS OR EXPECTATIONS;
(b) THE APP WILL BE UNINTERRUPTED, TIMELY, SECURE, OR ERROR-FREE;
(c) THE CONTENT ANALYSIS, SAFETY SCORES, OR AGE RECOMMENDATIONS WILL BE ACCURATE, COMPLETE, OR RELIABLE;
(d) ALL INAPPROPRIATE, HARMFUL, OR DANGEROUS CONTENT WILL BE IDENTIFIED AND FILTERED;
(e) ANY ERRORS IN THE APP WILL BE CORRECTED.

SOME JURISDICTIONS DO NOT ALLOW THE EXCLUSION OF CERTAIN WARRANTIES, SO SOME OF THE ABOVE EXCLUSIONS MAY NOT APPLY TO YOU.

12. LIMITATION OF LIABILITY

12.1 TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL THE COMPANY, ITS OFFICERS, DIRECTORS, EMPLOYEES, AGENTS, OR AFFILIATES BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO:
(a) DAMAGES FOR LOSS OF PROFITS, GOODWILL, DATA, OR OTHER INTANGIBLE LOSSES;
(b) DAMAGES RESULTING FROM CONTENT THAT BYPASSES THE FILTERING SYSTEM;
(c) EMOTIONAL DISTRESS ARISING FROM A CHILD'S EXPOSURE TO CONTENT THAT WAS NOT FILTERED;
(d) DAMAGES RESULTING FROM UNAUTHORIZED ACCESS TO OR ALTERATION OF YOUR DATA;
(e) DAMAGES RESULTING FROM THIRD-PARTY SERVICE OUTAGES (YouTube, Supabase, AI providers);
(f) DAMAGES RESULTING FROM ANY INTERRUPTION OF SERVICE.

12.2 OUR TOTAL AGGREGATE LIABILITY FOR ALL CLAIMS ARISING OUT OF OR RELATED TO THESE TERMS OR THE APP SHALL NOT EXCEED THE GREATER OF: (A) THE AMOUNTS YOU HAVE PAID TO US IN THE TWELVE (12) MONTHS PRECEDING THE CLAIM, OR (B) FIFTY DOLLARS (USD \$50.00).

12.3 SOME JURISDICTIONS DO NOT ALLOW THE LIMITATION OR EXCLUSION OF LIABILITY FOR CERTAIN DAMAGES, SO SOME OF THE ABOVE LIMITATIONS MAY NOT APPLY TO YOU. IN SUCH JURISDICTIONS, OUR LIABILITY IS LIMITED TO THE MAXIMUM EXTENT PERMITTED BY LAW.

13. INDEMNIFICATION

You agree to indemnify, defend, and hold harmless the Company and its officers, directors, employees, agents, and affiliates from and against any and all claims, damages, losses, liabilities, costs, and expenses (including reasonable attorneys' fees) arising out of or related to:
(a) Your use of the App;
(b) Your violation of these Terms;
(c) Your violation of any third party's rights;
(d) Content viewed by your children through the App;
(e) Claims brought by your children, their other parent or guardian, or any third party related to your or your children's use of the App;
(f) Your failure to supervise your children's use of the App;
(g) Inaccurate information you provide in your account or child profiles.

14. DISPUTE RESOLUTION AND ARBITRATION

PLEASE READ THIS SECTION CAREFULLY. IT AFFECTS YOUR LEGAL RIGHTS, INCLUDING YOUR RIGHT TO FILE A LAWSUIT IN COURT.

14.1 Informal Resolution: Before filing any formal dispute, you agree to contact us at legal@babymonitor.app and attempt to resolve the dispute informally for at least thirty (30) days.

14.2 Binding Arbitration: If the dispute is not resolved informally, you and the Company agree to resolve it through binding individual arbitration administered by the American Arbitration Association ("AAA") under its Consumer Arbitration Rules, or by JAMS under its Streamlined Arbitration Rules, at the claimant's election.

14.3 CLASS ACTION WAIVER: YOU AND THE COMPANY AGREE THAT EACH MAY BRING CLAIMS AGAINST THE OTHER ONLY IN YOUR OR ITS INDIVIDUAL CAPACITY AND NOT AS A PLAINTIFF OR CLASS MEMBER IN ANY PURPORTED CLASS, CONSOLIDATED, OR REPRESENTATIVE ACTION. The arbitrator may not consolidate more than one person's claims and may not preside over any form of class or representative proceeding.

14.4 Small Claims Exception: Either party may bring an individual action in small claims court for disputes within that court's jurisdictional limits.

14.5 Opt-Out: You may opt out of this arbitration agreement by sending written notice to legal@babymonitor.app within thirty (30) days of first creating your account. The notice must include your name, email address, and a clear statement that you wish to opt out of the arbitration agreement. If you opt out, the remainder of these Terms remains in effect.

14.6 Governing Law: These Terms and any disputes arising under them shall be governed by and construed in accordance with the laws of the State of Delaware, United States, without regard to its conflict of laws provisions.

14.7 Venue: For any dispute not subject to arbitration, you consent to the exclusive jurisdiction and venue of the state and federal courts located in the State of Delaware.

15. APPLE-SPECIFIC TERMS

If you downloaded the App from the Apple App Store, the following additional terms apply:

15.1 These Terms are between you and Baby Monitor App, not Apple Inc. ("Apple"). Apple is not responsible for the App or its content.
15.2 Apple has no obligation to furnish any maintenance and support services for the App.
15.3 In the event of any failure of the App to conform to any applicable warranty, you may notify Apple, and Apple will refund the purchase price (if any). To the maximum extent permitted by applicable law, Apple has no other warranty obligation with respect to the App.
15.4 Apple is not responsible for addressing any claims by you or any third party relating to the App, including product liability claims, claims that the App fails to conform to legal or regulatory requirements, or claims under consumer protection laws.
15.5 In the event of any third-party claim that the App or your use of the App infringes that third party's intellectual property rights, Apple will not be responsible for the investigation, defense, settlement, or discharge of such claim.
15.6 Apple and its subsidiaries are third-party beneficiaries of these Terms, and Apple will have the right to enforce these Terms against you as a third-party beneficiary.
15.7 You represent and warrant that: (a) you are not located in a country subject to a U.S. Government embargo; (b) you are not listed on any U.S. Government list of prohibited or restricted parties.

16. TERMINATION

16.1 You may terminate your account at any time by using the "Delete Account" feature in Account Settings or by emailing support@babymonitor.app.
16.2 We may suspend or terminate your account at any time, with or without notice, for conduct that we believe violates these Terms, is harmful to other users, or is otherwise objectionable.
16.3 Upon termination, your right to use the App ceases immediately. Data deletion follows our Privacy Policy.
16.4 The following sections survive termination: 5 (AI Disclaimer), 9 (IP), 11 (Warranty Disclaimer), 12 (Limitation of Liability), 13 (Indemnification), 14 (Arbitration), and 15 (Apple Terms).

17. MODIFICATIONS TO TERMS

17.1 We may modify these Terms at any time. Material changes will be communicated via in-app notification and email at least thirty (30) days before taking effect.
17.2 Your continued use of the App after the effective date of modified Terms constitutes acceptance of the changes.
17.3 If you disagree with the modified Terms, your sole remedy is to stop using the App and delete your account.

18. GENERAL PROVISIONS

18.1 Entire Agreement: These Terms, together with the Privacy Policy, Children's Privacy Notice, and any other legal documents referenced herein, constitute the entire agreement between you and the Company regarding the App.
18.2 Severability: If any provision of these Terms is found to be unenforceable, the remaining provisions will continue in full force and effect.
18.3 Waiver: Our failure to enforce any right or provision of these Terms shall not constitute a waiver of such right or provision.
18.4 Assignment: You may not assign or transfer these Terms without our prior written consent. We may assign these Terms without restriction.
18.5 Force Majeure: We shall not be liable for any failure or delay in performance due to circumstances beyond our reasonable control, including natural disasters, acts of government, internet outages, or third-party service failures.
18.6 Headings: Section headings are for convenience only and do not affect interpretation.
18.7 No Third-Party Beneficiaries: Except as expressly provided in Section 15 (Apple Terms), these Terms do not create any third-party beneficiary rights.

19. CONTACT US

For questions about these Terms:
Email: legal@babymonitor.app
Support: support@babymonitor.app
''';

  // ---------------------------------------------------------------------------
  // 3. CHILDREN'S PRIVACY NOTICE
  // ---------------------------------------------------------------------------
  static const String childrensPrivacyNotice =
      '''
CHILDREN'S PRIVACY NOTICE

Last Updated: $privacyPolicyLastUpdated

This Children's Privacy Notice supplements our main Privacy Policy and provides additional details about how Baby Monitor ("we," "us," "our") collects, uses, and protects information related to children in compliance with the Children's Online Privacy Protection Act (COPPA) and its amended rules.

1. OUR COMMITMENT

Baby Monitor is designed as a parental tool. We are committed to protecting the privacy and safety of children. We do not collect personal information directly from children. All information about children is provided and managed exclusively by their parent or legal guardian.

2. WHAT INFORMATION WE COLLECT ABOUT CHILDREN

The following information about children is collected when a parent creates and manages a child profile:

(a) First name - used to identify the child's profile within the App
(b) Date of birth - used solely to calculate the child's age for age-appropriate content filtering; stored to recalculate as the child ages
(c) Content filter sensitivity settings - numerical preferences (1-10 scale) for safety dimensions such as overstimulation tolerance, scariness tolerance, language strictness, and others
(d) Content type preferences - which categories of content (educational, nature, cartoons, music, etc.) are preferred, allowed, or blocked
(e) Watch history - which YouTube video IDs the child viewed, when, for how long, and whether viewing was completed
(f) Screen time sessions - when sessions started and ended, total duration, and which device was used
(g) Content filtering logs - which video IDs were blocked and the specific filter reasons
(h) Content schedule assignments (premium) - time blocks with allowed content types
(i) Video interruption logs - records of when a video was stopped mid-play due to new analysis results or parental setting changes

3. HOW WE COLLECT THIS INFORMATION

ALL child information is provided and managed exclusively by the authenticated parent or legal guardian. Children cannot:
- Create their own accounts
- Register their own profiles
- Modify their own profiles or settings
- Access the parent dashboard or settings

Kid mode is secured behind parental gates (biometric authentication, PIN, or age-appropriate verification challenge) that prevent children from accessing settings or exiting kid mode without parental authorization.

4. HOW WE USE CHILDREN'S INFORMATION

We use children's information solely for the following purposes:
(a) Provide age-appropriate content filtering based on the child's age and parent-configured sensitivity settings
(b) Enforce screen time limits, mandatory breaks, and bedtime schedules configured by the parent
(c) Generate activity reports (watch history, screen time summaries, filtered content logs) visible only to the parent
(d) Improve aggregate content filtering accuracy through anonymized, de-identified data

5. WHEN WE DISCLOSE CHILDREN'S INFORMATION

We do NOT disclose children's personal information to third parties. Specifically:
(a) AI Content Analysis: Only video metadata (title, description, tags, duration, transcript) is sent to AI providers for safety analysis. No child identifiers, names, ages, or viewing patterns are included.
(b) YouTube API: Calls are made server-side using API keys. No child identifiers are transmitted to YouTube.
(c) Analytics: Child identifiers are irreversibly hashed using SHA-256 before storage. The original identifier cannot be recovered.
(d) Community Ratings: Ratings are submitted by parents and linked to parent accounts, not to child profiles.

6. PARENTAL CONSENT

6.1 Before any child profile data is collected, we require verifiable parental consent through an in-app consent process where the parent must:
- Review a plain-language description of what data will be collected and how it will be used
- Provide granular consent for specific categories of data collection
- Enter their full legal name to acknowledge consent
- Accept the terms of this Children's Privacy Notice

6.2 Consent records are maintained with timestamps for legal compliance.
6.3 If we make material changes to how we collect or use children's information, we will obtain renewed parental consent before applying those changes.

7. PARENTAL RIGHTS

As a parent or legal guardian, you have the right to:
(a) Review: View all information collected about your child in the App's parent dashboard, including watch history, screen time data, and filter logs
(b) Delete: Delete your child's profile and all associated data at any time. Deletion is immediate and irreversible, removing all watch history, screen time data, filter logs, preferences, and content schedules
(c) Refuse: Refuse further collection of your child's information by deleting the child's profile
(d) Withdraw Consent: Withdraw your consent for child data collection at any time by deleting the child's profile or your entire account
(e) Portability: Request a copy of your child's data in a machine-readable format by emailing us

To exercise these rights, use the App's settings or email privacy@babymonitor.app.

8. DATA SECURITY FOR CHILDREN'S DATA

In addition to the security measures described in our main Privacy Policy:
(a) Row-level security policies in our database ensure that parents can only access data for their own children
(b) Parental gates (biometric, PIN, or challenge) prevent children from accessing the parent dashboard or modifying settings
(c) PIN codes are hashed using PBKDF2-HMAC-SHA256 with 100,000 iterations and unique salts
(d) Failed PIN attempts trigger exponential lockout (30 seconds to 1 hour) to prevent brute-force access

9. DATA RETENTION FOR CHILDREN'S DATA

(a) Watch history, screen time sessions, and content filtering logs: Automatically deleted after one (1) year
(b) Child profile data: Retained until the parent deletes the profile or account
(c) Upon account deletion: All child data is cascade-deleted immediately

10. CONTACT THE OPERATOR

If you have questions about this Children's Privacy Notice or wish to exercise your parental rights:

Baby Monitor App
Email: privacy@babymonitor.app
Support: support@babymonitor.app
''';

  // ---------------------------------------------------------------------------
  // 4. AI CONTENT FILTERING DISCLAIMER
  // ---------------------------------------------------------------------------
  static const String aiFilteringDisclaimer = '''
AI CONTENT FILTERING DISCLAIMER

Baby Monitor uses artificial intelligence to analyze YouTube video content across multiple safety dimensions. Please read and understand the following before using the App.

WHAT OUR AI DOES

Our AI analyzes video metadata, transcripts, visual frames, and audio to evaluate content across dimensions including overstimulation, scariness, educational value, language appropriateness, violence, and more. Each video receives safety scores and an age recommendation.

IMPORTANT LIMITATIONS

1. AI analysis is probabilistic, not deterministic. Results represent the AI's best assessment, not a guarantee.

2. No content filtering system, whether AI-powered or human-reviewed, can guarantee 100% accuracy. Inappropriate content may occasionally pass through filters (false negatives), and safe content may occasionally be blocked (false positives).

3. Accuracy varies depending on:
   - Video language (analysis is optimized for English content)
   - Cultural context and regional norms
   - Content type and production quality
   - Rapidly evolving content trends
   - Deliberate attempts to evade detection

4. New types of harmful content, obfuscation techniques, or trends may not be detected until our models are updated.

5. Analysis results for the same video may change over time as our AI models improve.

YOUR RESPONSIBILITIES AS A PARENT

- Periodically review the videos your child has watched and the filter decisions the App has made
- Adjust filter sensitivity settings based on your child's maturity and your family's values
- Use the manual approval and blocking features to override AI decisions when you disagree
- Do not rely solely on Baby Monitor or any automated tool to protect your children from inappropriate content
- Maintain active supervision of your children's media consumption

Baby Monitor is a tool that assists parents. It does not replace parental judgment or supervision.

By using Baby Monitor, you acknowledge these limitations and accept responsibility for supervising your children's content consumption.
''';

  // ---------------------------------------------------------------------------
  // 5. CCPA / CPRA PRIVACY NOTICE SUPPLEMENT
  // ---------------------------------------------------------------------------
  static const String ccpaNotice =
      '''
CALIFORNIA PRIVACY NOTICE (CCPA/CPRA SUPPLEMENT)

Last Updated: $privacyPolicyLastUpdated

This supplement applies to California residents and is provided pursuant to the California Consumer Privacy Act (CCPA) as amended by the California Privacy Rights Act (CPRA).

1. CATEGORIES OF PERSONAL INFORMATION COLLECTED

In the preceding twelve (12) months, we have collected the following categories of personal information:

(a) Identifiers: email address, display name, device identifiers
(b) Personal information under Cal. Civ. Code 1798.80(e): name
(c) Internet or electronic network activity: watch history, screen time data, content filtering logs, app interaction data
(d) Inferences drawn: age bracket calculations, content preference patterns
(e) Sensitive personal information: children's personal information (first name, date of birth)

2. SOURCES OF PERSONAL INFORMATION

We collect personal information directly from you when you create an account, create child profiles, and use the App.

3. BUSINESS PURPOSE FOR COLLECTION

We collect and use personal information for the operational purposes described in our main Privacy Policy, including providing content filtering, enforcing screen time limits, and improving the App.

4. SALE AND SHARING OF PERSONAL INFORMATION

WE DO NOT SELL YOUR PERSONAL INFORMATION.
WE DO NOT SHARE YOUR PERSONAL INFORMATION FOR CROSS-CONTEXT BEHAVIORAL ADVERTISING.

5. YOUR CALIFORNIA RIGHTS

(a) Right to Know: You have the right to request that we disclose the categories and specific pieces of personal information we have collected about you.
(b) Right to Delete: You have the right to request deletion of personal information we have collected from you, subject to certain exceptions.
(c) Right to Correct: You have the right to request correction of inaccurate personal information.
(d) Right to Opt-Out of Sale/Sharing: We do not sell or share personal information, so this right is not applicable. However, you may submit a request to confirm this status.
(e) Right to Limit Use of Sensitive Personal Information: You may request that we limit the use of your sensitive personal information (children's data) to purposes necessary to perform the service.
(f) Right to Non-Discrimination: We will not discriminate against you for exercising your CCPA rights. You will not receive different pricing, service quality, or access levels.

6. EXERCISING YOUR RIGHTS

To exercise your California rights, contact us at:
Email: privacy@babymonitor.app

We will verify your identity by matching information you provide with information in our records. We will respond within forty-five (45) days, with a possible forty-five (45) day extension if necessary.

7. AUTHORIZED AGENTS

You may designate an authorized agent to make requests on your behalf. The agent must provide your signed written authorization. We may still require you to verify your identity directly.

8. CALIFORNIA "SHINE THE LIGHT" LAW

We do not disclose personal information to third parties for their direct marketing purposes.

9. METRICS

In accordance with CCPA requirements, we will publish annual metrics regarding the number of requests to know, delete, and correct that we receive and how we responded.
''';

  // ---------------------------------------------------------------------------
  // 6. SUBSCRIPTION & AUTO-RENEWAL TERMS
  // ---------------------------------------------------------------------------
  static const String subscriptionTerms =
      '''
SUBSCRIPTION TERMS AND AUTO-RENEWAL DISCLOSURE

Last Updated: $termsLastUpdated

1. SUBSCRIPTION OPTIONS

Baby Monitor offers the following plans:
- Free Plan: 50 video analyses per month, 1 child profile, basic screen time limits
- Premium Plan: Unlimited video analyses, unlimited child profiles, full screen time controls, content scheduling, offline playlists, priority analysis

2. PRICING

Premium subscription: \$4.99 USD per month (or local equivalent). Prices may vary by region and are displayed in your local currency in the app store.

3. FREE TRIAL

New subscribers may be offered a 7-day free trial. During the trial, you have full access to Premium features. If you do not cancel before the trial ends, your subscription will automatically convert to a paid monthly subscription at the listed price.

4. PAYMENT

Payment will be charged to your Apple ID account (iOS) or Google Play account (Android) at the time of purchase confirmation, or at the end of the free trial period if applicable.

5. AUTOMATIC RENEWAL

Your subscription automatically renews unless it is canceled at least 24 hours before the end of the current billing period. Your account will be charged for renewal within 24 hours prior to the end of the current period at the then-current subscription price.

6. HOW TO MANAGE AND CANCEL YOUR SUBSCRIPTION

On iPhone/iPad:
1. Open the Settings app
2. Tap your name at the top
3. Tap "Subscriptions"
4. Select "Baby Monitor"
5. Tap "Cancel Subscription"

On Android:
1. Open the Google Play Store app
2. Tap your profile icon
3. Tap "Payments & subscriptions" then "Subscriptions"
4. Select "Baby Monitor"
5. Tap "Cancel subscription"

Cancellation takes effect at the end of the current billing period. You will continue to have access to Premium features until then.

7. REFUNDS

Refunds are handled by the respective app store (Apple or Google) according to their refund policies. We do not process refunds directly.

8. PRICE CHANGES

We reserve the right to change subscription pricing. We will notify you at least 30 days before any price change takes effect. The new price will apply at the start of your next billing period following the notice.
''';

  // ---------------------------------------------------------------------------
  // 7. THIRD-PARTY SERVICE DISCLOSURE
  // ---------------------------------------------------------------------------
  static const String thirdPartyDisclosure =
      '''
THIRD-PARTY SERVICE DISCLOSURE

Last Updated: $privacyPolicyLastUpdated

Baby Monitor integrates with the following third-party services to provide its features. This document describes each service, what data it receives, and where to find its privacy policy.

1. SUPABASE (Database and Authentication)
- Purpose: Stores all app data, handles user authentication
- Data received: All data described in our Privacy Policy (encrypted in transit and at rest)
- Hosting: Amazon Web Services (AWS), United States
- Compliance: SOC 2 Type II
- Privacy policy: https://supabase.com/privacy

2. YOUTUBE DATA API v3 (Google)
- Purpose: Retrieves video metadata (titles, descriptions, thumbnails, durations)
- Data sent: Search queries, video IDs, channel IDs
- Data NOT sent: Any personal information about parents or children
- Privacy policy: https://policies.google.com/privacy
- YouTube ToS: https://www.youtube.com/t/terms

3. PIPED API (Open-Source YouTube Alternative)
- Purpose: Fallback for video metadata retrieval when YouTube API quota is exhausted
- Data sent: Search queries, video IDs
- Data NOT sent: Any personal information
- Important: Piped instances are community-operated by volunteers. They do not have the same privacy guarantees as commercial services. No personal data is transmitted, but search queries pass through these servers.
- More info: https://github.com/TeamPiped/Piped

4. ANTHROPIC CLAUDE API (AI Content Analysis)
- Purpose: AI-powered safety analysis of video content
- Data sent: Video title, channel name, description (first 2,000 characters), tags (up to 20), duration, transcript (first 15,000 characters), and up to 12 extracted video frames
- Data NOT sent: Any personal information about parents or children (no names, emails, ages, device IDs, or viewing patterns)
- Privacy policy: https://www.anthropic.com/privacy

5. GOOGLE GEMINI API (Alternative AI Analysis)
- Purpose: Alternative AI provider for content safety analysis
- Data sent: Same as Anthropic Claude (video metadata, transcripts, frames only)
- Data NOT sent: Any personal information
- Privacy policy: https://policies.google.com/privacy

6. OPENAI API (Alternative AI Analysis)
- Purpose: Alternative AI provider for content safety analysis
- Data sent: Same as Anthropic Claude (video metadata, transcripts, frames only)
- Data NOT sent: Any personal information
- Privacy policy: https://openai.com/privacy

7. REVENUECAT (Subscription Management)
- Purpose: Manages in-app purchase subscriptions across platforms
- Data sent: Device identifier, subscription status
- Data NOT sent: Child data, email addresses, or personal information
- Privacy policy: https://www.revenuecat.com/privacy

8. APPLE APP STORE / GOOGLE PLAY STORE
- Purpose: App distribution, payment processing, in-app purchases
- Data sent: Purchase transactions (handled by the respective store, not by us)
- Privacy policies: https://www.apple.com/privacy and https://policies.google.com/privacy

9. LOCAL-ONLY MODELS (No Cloud Transmission)
The following AI models run entirely on our analysis server and do not transmit data to any external service:
- OpenAI Whisper (audio transcription)
- Detoxify (toxicity classification)
- HateSonar (hate speech detection)
- NSFW/violence classifiers (visual content analysis)
''';

  // ---------------------------------------------------------------------------
  // 8. ACCEPTABLE USE POLICY
  // ---------------------------------------------------------------------------
  static const String acceptableUsePolicy =
      '''
ACCEPTABLE USE POLICY

Last Updated: $termsLastUpdated

This Acceptable Use Policy ("AUP") governs your use of the Baby Monitor application. By using the App, you agree to comply with this AUP. Violations may result in suspension or termination of your account.

1. PROHIBITED CONDUCT

You may not:
(a) Attempt to circumvent, disable, or interfere with content filters, parental gates, screen time enforcement, or any other safety mechanism in the App
(b) Reverse-engineer, decompile, disassemble, or attempt to derive the source code of the App or its AI analysis pipeline
(c) Use automated means (bots, scrapers, crawlers) to access the App, its data, or its APIs
(d) Exploit bugs, vulnerabilities, or errors in the App for any purpose other than reporting them to us
(e) Submit false, fraudulent, misleading, or spam community ratings or feedback
(f) Attempt to manipulate community consensus scores through coordinated or deceptive activity
(g) Share your account credentials with any other person
(h) Create multiple accounts to circumvent usage limits or other restrictions
(i) Impersonate another person, entity, or user
(j) Use the App for any illegal purpose or in violation of any applicable law
(k) Interfere with, disrupt, or place an unreasonable burden on the App's infrastructure
(l) Collect, harvest, or store personal information about other users
(m) Provide unsupervised access to the App to children without configuring appropriate safety settings
(n) Attempt to access another user's account or data

2. CONTENT STANDARDS

When submitting community ratings or feedback, you must:
(a) Provide honest and accurate assessments
(b) Not use profane, threatening, or harassing language
(c) Not submit content that is illegal or promotes illegal activity

3. SECURITY

You are responsible for:
(a) Maintaining the security of your account, PIN, and biometric access
(b) Reporting any security vulnerabilities to security@babymonitor.app
(c) Not attempting to probe, scan, or test the vulnerability of the App without our explicit written consent

4. ENFORCEMENT

We may, at our sole discretion:
(a) Issue a warning for a first violation
(b) Temporarily suspend your account for repeated violations
(c) Permanently terminate your account for serious or persistent violations
(d) Remove or modify community ratings that violate this AUP
(e) Report illegal activity to appropriate authorities

5. REPORTING VIOLATIONS

To report a violation of this AUP, contact us at: abuse@babymonitor.app
''';

  // ---------------------------------------------------------------------------
  // 9. DMCA / COPYRIGHT POLICY
  // ---------------------------------------------------------------------------
  static const String dmcaPolicy =
      '''
COPYRIGHT AND DMCA POLICY

Last Updated: $termsLastUpdated

Baby Monitor respects the intellectual property rights of others and expects its users to do the same. This policy addresses copyright infringement in accordance with the Digital Millennium Copyright Act ("DMCA").

1. CONTENT ON THE APP

Baby Monitor does not host YouTube video content. Videos are played through YouTube's official embedded player. YouTube content is subject to YouTube's own copyright policies and Terms of Service.

Baby Monitor does host user-generated community ratings and feedback submitted by parents.

2. DMCA TAKEDOWN NOTICES

If you believe that content accessible through the App infringes your copyright, you may submit a DMCA takedown notice to our designated agent with the following information:

(a) A physical or electronic signature of the copyright owner or authorized agent
(b) Identification of the copyrighted work claimed to be infringed
(c) Identification of the material that is claimed to be infringing, with sufficient detail to locate it
(d) Your contact information (name, address, telephone, email)
(e) A statement that you have a good faith belief that the use is not authorized by the copyright owner, its agent, or the law
(f) A statement, under penalty of perjury, that the information in the notification is accurate and that you are the copyright owner or authorized to act on their behalf

Send DMCA notices to:
Email: dmca@babymonitor.app

3. COUNTER-NOTIFICATION

If you believe your content was removed in error, you may submit a counter-notification including:
(a) Your physical or electronic signature
(b) Identification of the material that was removed and its location before removal
(c) A statement under penalty of perjury that you have a good faith belief the material was removed by mistake or misidentification
(d) Your name, address, telephone number, and consent to jurisdiction of the federal district court for your address

4. REPEAT INFRINGER POLICY

We will terminate the accounts of users who are repeat copyright infringers. A user who receives three (3) valid DMCA notices will have their account permanently terminated.
''';

  // ---------------------------------------------------------------------------
  // 10. DATA BREACH NOTIFICATION POLICY
  // ---------------------------------------------------------------------------
  static const String dataBreachPolicy =
      '''
DATA BREACH NOTIFICATION POLICY

Last Updated: $privacyPolicyLastUpdated

Baby Monitor takes the security of your data seriously. This policy describes how we handle data security incidents.

1. WHAT CONSTITUTES A DATA BREACH

A data breach is any unauthorized access to, acquisition of, disclosure of, or loss of personal information that compromises the security, confidentiality, or integrity of such information.

2. OUR RESPONSE

Upon discovering a confirmed data breach affecting personal information, we will:

(a) Investigate: Immediately investigate the nature, scope, and cause of the breach
(b) Contain: Take immediate steps to contain and mitigate the breach
(c) Assess: Determine what personal information was affected and assess the risk to affected individuals
(d) Notify Authorities: Report the breach to relevant supervisory authorities within seventy-two (72) hours of becoming aware of the breach (as required by GDPR) or as required by applicable state and federal law
(e) Notify Affected Users: Notify affected users without undue delay, and no later than required by applicable law

3. NOTIFICATION CONTENT

Our notification to affected users will include:
(a) A description of the nature of the breach
(b) The types of personal information involved
(c) What steps we have taken to address the breach
(d) What steps you can take to protect yourself
(e) Our contact information for further questions

4. CHILDREN'S DATA

If a breach involves children's personal information, we will:
(a) Prioritize notification to affected parents
(b) Provide specific guidance on protecting children's information
(c) Report to the Federal Trade Commission as required under COPPA

5. RECORD KEEPING

We maintain records of all data security incidents, including those that do not require user notification, for a minimum of five (5) years.

6. CONTACT

To report a security vulnerability or suspected breach:
Email: security@babymonitor.app
''';

  // ---------------------------------------------------------------------------
  // 11. ACCESSIBILITY STATEMENT
  // ---------------------------------------------------------------------------
  static const String accessibilityStatement =
      '''
ACCESSIBILITY STATEMENT

Last Updated: $termsLastUpdated

Baby Monitor is committed to ensuring the App is accessible to all users, including those with disabilities.

1. OUR GOAL

We aim to conform to the Web Content Accessibility Guidelines (WCAG) 2.1 at Level AA, as adapted for mobile applications.

2. WHAT WE ARE DOING

(a) Using semantic widgets and labels to support screen readers (TalkBack on Android, VoiceOver on iOS)
(b) Maintaining sufficient color contrast ratios for text and interactive elements
(c) Supporting dynamic text sizing and system font scaling
(d) Providing alternative text descriptions for icons and images
(e) Ensuring all interactive elements are keyboard and switch-accessible
(f) Testing with assistive technologies during development

3. KNOWN LIMITATIONS

(a) YouTube video content is provided by YouTube's embedded player and may have accessibility limitations outside our control
(b) Some complex interactive elements (e.g., drag-to-rank filter setup) may have limited accessibility on certain devices; we are working to improve these
(c) TV mode interfaces are optimized for remote control navigation and may differ from phone/tablet experiences

4. FEEDBACK

If you encounter an accessibility barrier, please contact us:
Email: accessibility@babymonitor.app

We welcome your feedback and will make reasonable efforts to address accessibility issues promptly.
''';
}
