<?php

/** Display constant list of servers in login form
* @link http://www.adminer.org/plugins/#use
* @author Jakub Vrana, http://www.vrana.cz/
* @license http://www.apache.org/licenses/LICENSE-2.0 Apache License, Version 2.0
* @license http://www.gnu.org/licenses/gpl-2.0.html GNU General Public License, version 2 (one or other)
*/
class AdminerLoginDatabases {
	/** @access protected */
	var $databases;
	
	function AdminerLoginDatabases($databases) {
		$this->databases = $databases;
		$this->titles = array();
		foreach ($databases as $key => $value) {
			$this->titles[$key] = $value["title"];
		}
	}
	
	function credentials() {
		$params = $this->databases[DB];
		return array($params["server"], $params["username"], $params["password"]);
	}

	function login($login, $password) {
		if (array_key_exists(DB, $this->databases)) {
			return;
		}
		return false;
	}

	function database() {
		return $this->databases[DB]["database"];
	}

	function databases() {
		return $this->titles;
	}

	function name() {
		if ($this->databases[DB]["wikipage"]) {
			return '<a href="'.$this->databases[DB]["wikipage"].'">Wiki page</a>';
		} else {
			return "Adminer";
		}
	}

	function loginForm() {
		?>
<table cellspacing="0">
<tr><th>Select Database<td><select name="auth[db]" onchange="this.form.submit();"><?php echo optionlist($this->titles); ?></select>
</table>
<p><input type="submit" value="Connect">

<input type="hidden" name="auth[username]" value="">	
<input type="hidden" name="auth[password]" value="">	
<input type="hidden" name="auth[driver]" value="server">	
<?php
		return true;
	}
	
}