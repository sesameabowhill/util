<?php
class AdminerStickyClientId {

	function selectSearchProcess($fields, $indexes) {
		restart_session();

		if (array_key_exists("select", $_GET) && $_GET["select"] == "client") {
			$this->setSessionClientUsername(null);
		}

		// filter client id condition from list of all conditions
		$client_id_condition = null;
		$filtered_conditions = array();
		if (array_key_exists("where", $_GET)) {
			foreach ($_GET["where"] as $condition) {
				if ($condition["col"] == "client_id") {
					$client_id_condition = $condition;
				} else {
					array_push($filtered_conditions, $condition);
				}
			}
		}
		$client_id_action = (array_key_exists("client-id-action", $_GET) ? $_GET["client-id-action"] : "");
		//var_dump($client_id_action);

		// reset client id condition if user asked for it
		if ($client_id_action == "remove") {
			$client_id_condition = null;
			$this->setSessionClientId(null);
		}
		// restore client id from session
		if ($client_id_condition == null && array_key_exists("client_id", $fields)) {
			$session_client_id = $this->getSessionClientId();
			if ($session_client_id != null) {
				$client_id_condition = array(
					"col" => "client_id",
					"op" => "=",
					"val" => $session_client_id,
				);
			}
		}

		// put client id condtion to first position
		if ($client_id_condition != null) {
			array_unshift($filtered_conditions, $client_id_condition);
		}

		// don't append client id if other conditions are set by user
		if ($client_id_action == "add" || $client_id_action == "remove") {
			$_GET["where"] = $filtered_conditions;
		} else {
			if (!array_key_exists("where", $_GET)) {
				$_GET["where"] = $filtered_conditions;
			}
		}
		
		if ($client_id_condition != null) {
			$client_id = $this->getClientId($client_id_condition);
			if ($client_id != null) {
				$this->setSessionClientId($client_id);
				$username = $this->getSessionClientUsername();
				if ($username == null) {
					$this->setSessionClientUsername($this->getUsernameByClientId($client_id));
				}
			}
		}

		// HACK to force save
		session_write_close();
	}
		
	function selectSearchPrint($where, $columns, $indexes) {
		if (array_key_exists("client_id", $columns)) {
			$client_id_condition = null;
			if (array_key_exists("where", $_GET)) {
				foreach ($_GET["where"] as $condition) {
					if ($condition["col"] == "client_id") {
						$client_id_condition = $condition;
					}
				}
			}


			$client_id = $this->getSessionClientId();
			if ($client_id != null) {
				echo '<fieldset><legend><a href="#fieldset-client-id" onclick="return !toggle(\'fieldset-client-id\');">Client</a></legend>';
				echo '<div id="fieldset-client-id"><div>';
				echo '<input style="float: left; margin-right: 0.5em; margin-left: 0px" type="checkbox" id="remember-client-id" ';
				echo 'onchange="document.getElementById(\'client-id-action\').value = (this.checked?\'add\':\'remove\')"';
				echo ($client_id_condition == null ? "" : " checked");
				echo '><input type="hidden" name="client-id-action" id="client-id-action" value="0">';

				echo '<label for="remember-client-id" title="';
				echo ($client_id_condition == null ? "Check to add condition" : "Uncheck to remove condition");
				echo '">';
				$username = $this->getSessionClientUsername();
				if ($username == null) {
					echo "id: ".$client_id;
				} else {
					echo "".$username."<br>id: ".$client_id;
				}
				echo '</label> ';
				echo '</div></div></fieldset>';
			}
		}
	}

	function getUsernameByClientId($client_id) {
		$result = connection()->query("SELECT cl_username FROM client WHERE id=".q($client_id));
		if ($result !== false) {
			$row = $result->fetch_row();
			if (is_array($row)) {
				return $row[0];
			}
		}
		return null;
	}

	function getClientId($condition) {
		if (($condition["op"] == '=' || $condition["op"] == 'LIKE') && preg_match('/^\d+$/', $condition["val"])) {
			return $condition["val"];
		} else {
			return null;
		}
	}

	function setSessionClientId($client_id) {
		if ($this->getSessionClientId() != $client_id) {
			$this->setSessionClientUsername(null);
		}
		$this->setSessionValue("remember-client-id", $client_id);
	}

	function getSessionClientId() {
		return $this->getSessionValue("remember-client-id");
	}

	function setSessionClientUsername($client_username) {
		$this->setSessionValue("remember-client-username", $client_username);
	}

	function getSessionClientUsername() {
		return $this->getSessionValue("remember-client-username");
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
