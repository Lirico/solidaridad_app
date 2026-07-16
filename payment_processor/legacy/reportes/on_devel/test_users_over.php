#!/usr/bin/php
<?php
// Parametros de base de datos
$db_host = "192.168.100.6";
$db_name = "kigsolidario2";
$user_name="kigadmin2";
$user_pass="mar89\$an2-";

$ngob = file($argv[1]);
$cdoc = count($ngob);

$i=0;

$con = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

for($i=0; $i<$cdoc; $i++)
{

$ndoc = trim($ngob[$i], "\n");

//  SUM -> sgas_usuario_cta

$sql = "select sum(importe) from sgas_usuario_cta where (fecha_operacion between '2017-11-01'and '2017-11-30') ".
       "and id_usuario='".$ndoc."';";

$qret = mysqli_multi_query($con, $sql) or die("valida de mas MYSQL: ".mysqli_error($con)."\n");

$res = mysqli_store_result($con);

$row = mysqli_fetch_array($res);

$sum_cta = $row[0];

mysqli_free_result($res);

// SUM -> repoter_diaria

$sql = "select sum(cantidad_kilo) from reporte_diaria where (fecha_tr between '2017-11-01' and '2017-11-30') ".
       "and nro_doc='".$ndoc."';";

$qret = mysqli_multi_query($con, $sql) or die("valida de mas MYSQL: ".mysqli_error($con)."\n");

$res = mysqli_store_result($con);

$row = mysqli_fetch_array($res);

$sum_rep = $row[0];

mysqli_free_result($res);

print("DOC: ".$ndoc." -> SUM(CTA) = ".$sum_cta."  SUM(REP) = ".$sum_rep."\n");

}


mysqli_close($con);

?>
