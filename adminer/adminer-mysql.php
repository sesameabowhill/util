<?php
function adminer_object() {
    // required to run any plugin
    include_once "./adminer-plugin.inc.php";

    include_once "./adminer-ConventionsForeignKeys.inc.php";
    include_once "./adminer-foreign-system.inc.php";
    include_once "./adminer-versioned-tables.inc.php";
    include_once "./adminer-login-databases.inc.php";
    if (file_exists("./databases.inc.php")) {
        include_once "./databases.inc.php";
    }
    
    $plugins = array(
        // specify enabled plugins here
        new ConventionForeignKeys,
        new AdminerForeignSystem,
        new AdminerVersionedTables
    );
    if (isset($databases)) {
        array_push($plugins, new AdminerLoginDatabases($databases));
    }

    return new AdminerPlugin($plugins);
}

// include original Adminer or Adminer Editor
include "./adminer-core.inc.php";
?>