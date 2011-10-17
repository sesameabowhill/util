<?php
function adminer_object() {
    // required to run any plugin
    include_once "./adminer-plugin.php";

    include_once "./adminer-ConventionsForeignKeys.php";
    include_once "./adminer-foreign-system.php";
    
    $plugins = array(
        // specify enabled plugins here
        new ConventionForeignKeys,
        new AdminerForeignSystem
    );
    
    /* It is possible to combine customization and plugins:
    class AdminerCustomization extends AdminerPlugin {
    }
    return new AdminerCustomization($plugins);
    */
    
    return new AdminerPlugin($plugins);
}

// include original Adminer or Adminer Editor
include "./adminer-core.php";
?>