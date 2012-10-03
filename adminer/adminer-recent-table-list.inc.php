<?php
class AdminerRecentTableList {

	function tablesPrint($tables) {
		echo "<p id='tables-recent' onmouseover='menuOver(this, event);' onmouseout='menuOut(this);'>\n";

		restart_session();
		$recent_tables = $this->getSessionValue("recent_tables");
		if (!$recent_tables) {
			$recent_tables = array();
		}
		if (array_key_exists("select", $_GET)) {
			$recent_tables[$_GET["select"]] = 1;
		}
		if (count(array_keys($recent_tables)) > 10) {
			$keys_to_remove = array_slice(array_keys($recent_tables), 10);
			foreach ($keys_to_remove as $key) {
				unset($key);
			}
		}
		$this->setSessionValue("recent_tables", $recent_tables);
		// HACK to force save
		session_write_close();

		foreach ($tables as $table => $type) {
			if (array_key_exists($table, $recent_tables)) {
				echo '<a href="' . h(ME) . 'select=' . urlencode($table) . '"' . bold($_GET["select"] == $table) . ">select</a> ";
				echo '<a href="' . h(ME) . 'table=' . urlencode($table) . '"' . bold($_GET["table"] == $table) . " title='Show structure'>" . $table . "</a><br>\n"; 
			}
		}
	}

	function setSessionValue($key, $value) {
		if (!get_session($key)) {
			set_session($key, array());
		}
		$session_value = get_session($key);
		$session_value[DB] = $value;

		set_session($key, $session_value);
	}

	function getSessionValue($key) {
		if (!get_session($key)) {
			set_session($key, array());
		}
		$session_value = get_session($key);
		return $session_value[DB];
	}

}
