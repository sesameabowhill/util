<?php
class AdminerVersionedTables {
	function backwardKeys($table, $tableName) {
		$versioned_views = array(
			'account' => 0,
			'address' => 0,
			'appointment_procedure' => 0,
			'appointment' => 1,
			'email' => 1,
			'insurance_contract' => 0,
			'ledger' => 0,
			'office' => 1,
			'patient_referrer' => 0,
			'patient_staff' => 0,
			'phone' => 1,
			'procedure' => 1,
			'recall' => 1,
			'referrer' => 1,
			'responsible_patient' => 1,
			'staff' => 0,
			'treatment_plan' => 0,
			'visitor' => 1,
		);
		if (array_key_exists($table, $versioned_views)) {
			$r = array(
				$table . "_versioned" => array(
					"from" => "id",
					"to" => "id",
					"name" => "versioned",
				),
			);
			if ($versioned_views[$table]) {
				$r[$table . "_user_sensitive"] = array(
					"from" => "id",
					"to" => $table."_id",
					"name" => "user sensitive",
				);
			}
			return $r;
		} else {
			return array();
		}
	}

	function backwardKeysPrint($backwardKeys, $row) {
		foreach ($backwardKeys as $table => $params) {
			print '<a href="'.h(ME).'&select='.$table.'&where[0][col]='.$params["to"].'&where[0][op]==&where[0][val]='.$row[$params["from"]].'">'.$params["name"].'</a> ';
		}
	}
}
