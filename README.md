# Description
- When a Player types in chat, a Floating Message appears above their head, visible to nearby Players who can see and read it.

![20251211233926_1](https://github.com/user-attachments/assets/fd607de2-2608-4d82-805e-6dde8353fcce)

# More
- **Supports** All Languages. **(Probably)**
- **Supports** 32+ Player Servers. **(Probably)**
- **Supports** **[Basecomm](https://github.com/alliedmodders/sourcemod/blob/master/plugins/basecomm.sp)** and **[SourceComms](https://github.com/sbpp/sourcebans-pp)**.
- **Supports** Say Team, Team Chat Annotations are only visible to Teammates.
- **Annotations** do **Not Penetrate Walls**.
- **Spy Cloak / Disguise**, Chat Annotation Not Working.

# Difference From [TF2-ChatBubbles](https://github.com/DosMike/TF2-ChatBubbles)
- **ConVar Mores**.
- **No Dependencies**.
- **Supports Ban Gag / Silence**.

# ConVar
- `sm_cvann_version`        `"6.5.0"`             **(Default)** - _Version of TF2Chat Annotations._
- `sm_cvann_enable`         `"1"`                 **(Default)** - _TF2Chat Annotations. (1 = Enable, 0 = Disable)_
- `sm_cvann_range`          `"25"`                **(Default)** - _Distance to See Annotations._
- `sm_cvann_show_range`     `"0"`                 **(Default)** - _Show Distance to speaker in Annotations. (1 = Enable, 0 = Disable)_
- `sm_cvann_show_msg`       `"1"`                 **(Default)** - _Allow Players to See their own Chat Annotation. (1 = Enable, 0 = Disable)_
- `sm_cvann_show_cmd`       `"1"`                 **(Default)** - _Command Visibility. (0 = Hide ! and /, 1 = Show !, 2 = Show /, 3 = Show ! and /)_
- `sm_cvann_interval`       `"0.5"`               **(Default)** - _Update interval for checking Annotation Visibility._
- `sm_cvann_lifetime`       `"10.0"`              **(Default)** - _How long Message stays visible (Seconds)._
- `sm_cvann_limit`          `"5"`                 **(Default)** - _Maximum Number of Annotations shown at same time. (0 = Unlimited)_
- `sm_cvann_maxlen`         `"64"`                **(Default)** - _Maximum Length of Chat Message shown in Annotations._
- `sm_cvann_entity_remove`  `"1900"`              **(Default)** - _Remove All Annotations if Entity count reaches this._
- `sm_cvann_entity_block`   `"2000"`              **(Default)** - _Block New Annotations if Entity count reaches this._
