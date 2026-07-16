<?php
include("include/params.inc");

function RepoMensualGobernacion($con, $periodo, $str_per)
{
	$ret = 0;

	$sql = "SELECT rpt.ciudad, rpt.barrio, rpt.fecha_tr, rpt.hora_tr, LPAD(cast(rpt.id_carga as char(12)),12,'0') id_tran, ".
       "rpt.nro_doc, rpt.apellido_nombre, rpt.periodo, rpt.prod_id, ".
       "rpt.cantidad_kilo, rpt.codigo_proveedor, rpt.ubicacion_entrega, rpt.tipo_trans, rpt.anulado ".
       "FROM kigsolidario2.reporte_diaria rpt ".
       "WHERE rpt.periodo = '".$periodo."' ".
       "ORDER BY rpt.id_carga";

	$res = mysqli_query($con, $sql) or die(mysqli_error($con));

	if (mysqli_num_rows($res) > 0)
	{
		$repo_fs = fopen("REP-PER".$str_per.".csv", "w") or die("No es posible crear el archivo.");

		while ($row = mysqli_fetch_assoc($res))
		{
			$line = $row['ciudad'].";".$row['barrio'].";".$row['fecha_tr'].";".$row['hora_tr'].";".$row['id_tran'].";".$row['nro_doc'].";".
			$row['apellido_nombre'].";".$row['periodo'].";".$row['prod_id'].";".$row['cantidad_kilo'].";".$row['codigo_proveedor'].";".
			$row['ubicacion_entrega'].";".$row['tipo_trans'].";".$row['anulado']."\n";

			//print($line);

			fwrite($repo_fs, $line);
		}

		fclose($repo_fs);
	} else {
		print("ERROR en generacion de reporte. NUM ROWS = 0\n");
		$ret = -1;
	}

	mysqli_free_result($res);

	return $ret;
}

function RepoDiarioGobernacion($con, $periodo, $str_per)
{
	$ret = 0;

	$sql = "SELECT rpt.ciudad, rpt.barrio, rpt.fecha_tr, rpt.hora_tr, LPAD(cast(rpt.id_carga as char(12)),12,'0') id_tran, ".
           "rpt.nro_doc, rpt.apellido_nombre, rpt.periodo, rpt.prod_id, ".
           "rpt.cantidad_kilo, rpt.codigo_proveedor, rpt.ubicacion_entrega, rpt.tipo_trans, rpt.anulado ".
           "FROM kigsolidario2.reporte_diaria rpt ".
           "WHERE fecha_tr='2022-05-31' ".
           "ORDER BY rpt.id_carga";

	$res = mysqli_query($con, $sql) or die(mysqli_error($con));

	if (mysqli_num_rows($res) > 0)
	{
		$repo_fs = fopen("REP-DIA".$str_per.".csv", "w") or die("No es posible crear el archivo.");

		while ($row = mysqli_fetch_assoc($res))
		{
			$line = $row['ciudad'].";".$row['barrio'].";".$row['fecha_tr'].";".$row['hora_tr'].";".$row['id_tran'].";".$row['nro_doc'].";".
			$row['apellido_nombre'].";".$row['periodo'].";".$row['prod_id'].";".$row['cantidad_kilo'].";".$row['codigo_proveedor'].";".
			$row['ubicacion_entrega'].";".$row['tipo_trans'].";".$row['anulado']."\n";

			//print($line);

			fwrite($repo_fs, $line);
		}

		fclose($repo_fs);
	} else {
		print("ERROR en generacion de reporte. NUM ROWS = 0\n");
		$ret = -1;
	}


	mysqli_free_result($res);

	return $ret;
}

// MAIN FUNCTION

$conn = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

$per=date('Y-')."06-01";
$sper = date('Ym');

RepoMensualGobernacion($conn, $per, $sper);

$ayer_ma = date('Ym');
$ayer_d = date('d') - 1;

if ($ayer_d < 10)
{
    $ayer_d = "0".$ayer_d;
}

$ayer = $ayer_ma.$ayer_d;

print("AYER: ".$ayer."\n");

//RepoDiarioGobernacion($conn, $per, "20211130");
RepoDiarioGobernacion($conn, "2022-06-01", "20220531");

mysqli_close($conn);

?>
