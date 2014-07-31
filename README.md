Dota2Soccer
===========

This project is a Dota2 mod, soccer like, the objective being to get a ball to the defended enemy's goal.

Code based on [barebones](https://github.com/bmddota/barebones/) with [d2tool](https://github.com/D2Modding/d2tool).

Some ideas are from real-life soccer, my imagination, and other soccer mods from starcraft or warcraft.

to launch locally :

    dota_local_addon_enable 1;
    dota_local_addon_game candySoccer;
    dota_local_addon_map myaddon;
    dota_force_gamemode 15;
    update_addon_paths;
    dota_wait_for_players_to_load 0;
    dota_wait_for_players_to_load_timeout 10;
    map myaddon;

For more informations about things to come : https://trello.com/b/pSIEX562/dota2soccer