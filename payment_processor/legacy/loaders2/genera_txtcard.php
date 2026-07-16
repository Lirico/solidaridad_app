#!/usr/bin/php
<?php
include("./include/params.inc");
include("./include/varias.inc");

// MAIN

$con = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

//$sql= "SELECT SUBSTRING(nro_tarjeta, 8, 7) usr FROM sgas_usuario WHERE fecha_alta=CURRENT_DATE() AND nro_doc='".$argv[1]."'" ;
$sql= "SELECT SUBSTRING(nro_tarjeta, 8, 7) FROM sgas_usuario WHERE nro_doc='".$argv[1]."'" ;

echo "INPUT = ".$argv[1]."\n";
echo "SQL = ".$sql."\n";

$result = mysqli_query($con, $sql) or die(mysqli_error($con));

$row = mysqli_fetch_array($result);

$nro_usuario = $row[0];

$sql = "call gen_mod2_cvv (".$nro_usuario.")";

echo "INPUT = ".$nro_usuario."\n";
echo "SQL = ".$sql."\n";

mysqli_free_result($result);

$result = mysqli_query($con, $sql) or die(mysqli_error($con));

mysqli_close($con);

?>
