Tag: template-uses-unsplit-choices
Severity: warning
Check: debian/debconf
Explanation: The use of &lowbar;Choices in templates is deprecated.
 A &lowbar;Choices field must be translated as a single string.
 .
 Using &lowbar;&lowbar;Choices allows each choice to be translated separately, easing
 translation and is therefore recommended.
 .
 Instead of simply replacing all occurrences of "&lowbar;Choices" by "&lowbar;&lowbar;Choices",
 apply the method described in po-debconf(7) under "SPLITTING CHOICES
 LIST", to avoid breaking existing translations.
 .
 If in doubt, please ask for help on the debian-i18n mailing list.
See-Also: po-debconf(7)
