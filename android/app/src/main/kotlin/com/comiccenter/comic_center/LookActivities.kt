package com.comiccenter.comic_center

// One launcher entry point per look. They exist only so each can carry its
// own manifest theme (splash background + icon) and launcher icon; all
// behaviour lives in MainActivity. Exactly one is enabled at a time — see
// MainActivity.setLauncherAlias and AndroidManifest.xml.
class MainActivitySumi : MainActivity()

class MainActivityCinema : MainActivity()

class MainActivityPastel : MainActivity()
