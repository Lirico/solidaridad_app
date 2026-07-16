<?php
include("include/params.inc");

function RepoProveedores($con, $rsocial, $str_per, $fecha_ini, $fecha_fin, $pfix)
{
	$ret = 0;

	print("Razon Social = ".$rsocial."\n");
	print("STR PER = ".$str_per."\n");
	//print("FECHA INI = ".$fecha_ini."\n");
	print("FECHA INI = ".$fecha_fin."\n");
	print("FECHA FIN = ".$fecha_fin."\n");
	print("Prefix = ".$pfix."\n");

	//$sql = "call ReporteProveedoresByTRACO3('".$rsocial."', '%', '%', '".$fecha_ini."', '".$fecha_fin."')";
	$sql = "call ReporteProveedoresByTRACO3('".$rsocial."', 'null', 'null', '".$fecha_ini."', '".$fecha_fin."')";

	$qret = mysqli_multi_query($con, $sql) or die("RepoProveedores() MYSQL: ".mysqli_error($con)."\n");

	$res = mysqli_store_result($con);

	if (mysqli_num_rows($res) > 0)
	{
		$repo_fs = fopen($pfix."-".$str_per.".csv", "w") or die("No es posible crear el archivo.");

		while ($row = mysqli_fetch_array($res))
		{
			$line = $row[0].";".$row[1].";".$row[2].";".$row[3].";".$row[4].";".$row[5].";".$row[6].";".
			        $row[7].";".$row[8].";".$row[9].";".$row[10].";".$row[11].";".$row[12].";".
			        $row[13].";".$row[14].";".$row[15].";".$row[16].";".$row[17]."\n";

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

$per=date('Y-')."07-01";
$sper = date('Ym');

$f_ini = date('Y-m')."-01";
$f_fin = date('Y-m-d');

$ayer_ma = date('Y-m');
$ayer_d = date('d') - 1;

if ($ayer_d < 10)
{
	$ayer_d = "0".$ayer_d;
}


$ayer = $ayer_ma."-".$ayer_d;

RepoProveedores($conn, $argv[1], $sper, $ayer, $ayer, $argv[2]);

mysqli_close($conn);

?>
