#!/usr/bin/php
<?php
include("include/params.inc");

function randomDate($start_date, $end_date)
{
    $min = strtotime($start_date);
    $max = strtotime($end_date);

    $val = rand($min, $max);

    //return date('Y-m-d H:i:s', $val);
    return $val;
}

// MAXIMOS
$consulta=1212;
$denegada=747;
$reverso=21;

$fechaIni="2018-09-01 00:00:01";
$fechaFin="2018-09-14 23:59:59";
$fechaFinCON=$fechaFin;
//$fechaFinCON="2017-12-30 23:59:59";

////////////////////////////////////////////////////////////////

// contadores
$consulta_cx=0;
$denegada_cx=0;
$reverso_cx=0;


// TIPOS DE TRX
$tp_trans = array();
$tp_trans[0] = "CON.SALDO";
$tp_trans[1] = "DENEGADA";
$tp_trans[2] = "REVERSO";


// MAIN ()

// CON.SALDO
$salir = 1;

while($salir)
{
	$conn = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

	$sql = "SELECT localidad, apellido_nombre FROM sgas_usuario WHERE situacion='V'";

	$res = mysqli_query($conn, $sql) or die(mysqli_error($conn));

	if (mysqli_num_rows($res) > 0)
	{
    	while ($mrow = mysqli_fetch_assoc($res))
    	{
    		$rndDate = randomDate($fechaIni, $fechaFinCON);

			$hora = date('H:i:s', $rndDate);
			$fecha = date('Y-m-d', $rndDate);

			// INSERT en la BBDD

			$rndProd = rand(1, 5);

			$sql2 = "INSERT INTO repo_all_tr (localidad,tr_date,tr_time,id_carga,nombre,prod_gob,tipo_trans,cantidad_kilo) VALUES ".
			"('".$mrow['localidad']."', '".$fecha."', '".$hora."', 0, '".$mrow['apellido_nombre']."', '".$rndProd."', 'CON.SALDO', 0.00)";

			$res2 = mysqli_query($conn, $sql2) or die(mysqli_error($conn));

			$consulta_cx = $consulta_cx + 1;

			if ($consulta_cx >= $consulta)
			{
				$salir=0;
				break;
			}
		}
	}

	mysqli_free_result($res);
	mysqli_close($conn);
}

// DENEGADA

$salir = 1;
while($salir)
{
	$conn = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

	$sql = "SELECT localidad, apellido_nombre FROM sgas_usuario WHERE situacion='V'";

	$res = mysqli_query($conn, $sql) or die(mysqli_error($conn));

	if (mysqli_num_rows($res) > 0)
	{
    	while ($mrow = mysqli_fetch_assoc($res))
    	{
    		$rndDate = randomDate($fechaIni, $fechaFin);

			$hora = date('H:i:s', $rndDate);
			$fecha = date('Y-m-d', $rndDate);

			// INSERT en la BBDD

			$rndProd = rand(1, 5);

			$sql2 = "INSERT INTO repo_all_tr (localidad,tr_date,tr_time,id_carga,nombre,prod_gob,tipo_trans,cantidad_kilo) VALUES ".
			"('".$mrow['localidad']."', '".$fecha."', '".$hora."', 0, '".$mrow['apellido_nombre']."', '".$rndProd."', 'DENEGADA', 0.00)";

			$res2 = mysqli_query($conn, $sql2) or die(mysqli_error($conn));

			$denegada_cx = $denegada_cx + 1;

			if ($denegada_cx >= $denegada)
			{
				$salir=0;
				break;
			}
		}
	}

	mysqli_free_result($res);
	mysqli_close($conn);
}


// REVERSO

$salir = 1;
while($salir)
{
	$conn = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

	$sql = "SELECT localidad, apellido_nombre FROM sgas_usuario WHERE situacion='V'";

	$res = mysqli_query($conn, $sql) or die(mysqli_error($conn));

	if (mysqli_num_rows($res) > 0)
	{
    	while ($mrow = mysqli_fetch_assoc($res))
    	{
    		$rndDate = randomDate($fechaIni, $fechaFin);

			$hora = date('H:i:s', $rndDate);
			$fecha = date('Y-m-d', $rndDate);

			// INSERT en la BBDD

			$rndProd = rand(1, 5);

			$sql2 = "INSERT INTO repo_all_tr (localidad,tr_date,tr_time,id_carga,nombre,prod_gob,tipo_trans,cantidad_kilo) VALUES ".
			"('".$mrow['localidad']."', '".$fecha."', '".$hora."', 0, '".$mrow['apellido_nombre']."', '".$rndProd."', 'REVERSO', 0.00)";

			$res2 = mysqli_query($conn, $sql2) or die(mysqli_error($conn));

			$reverso_cx = $reverso_cx + 1;

			if ($reverso_cx >= $reverso)
			{
				$salir=0;
				break;
			}
		}
	}

	mysqli_free_result($res);
	mysqli_close($conn);
}


?>
