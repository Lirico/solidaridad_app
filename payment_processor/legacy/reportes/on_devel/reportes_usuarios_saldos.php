<?php
include("include/params.inc");

function check_saldo($con, $card, $prod, $from_date, $to_date )
{
   $sql = "select id_usuario,nro_tarjeta,fecha_operacion,cod_operacion,importe,saldo,prod_id,id_cierre,ts_operacion,id_tr  from sgas_usuario_cta ".
"where ".
"nro_tarjeta='".$card."' ".
"and prod_id='".$prod."' ".
"and fecha_operacion between '".$from_date."' and '".$to_date."' ".
"order by id_tr desc ".
"limit 1 ";

   $res = mysqli_query($con, $sql) or die(mysqli_error($con));

   $row = mysqli_fetch_assoc($res);

   return $row;
}

// PARAMETROS

$producto=$argv[1];
$date_from=$argv[2];
$date_to=$argv[3];

////////////////////////////

$conn = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());


if (isset($argv[4]))
{
   $paccount=$argv[4];

   $row =check_saldo($conn, $paccount, $producto, $date_from, $date_to);

   $line = $row['id_usuario']." ".$row['nro_tarjeta']." ".$row['fecha_operacion']." ".$row['cod_operacion']." ".$row['importe']." ".$row['saldo'].
           " ".$row['prod_id']." ".$row['id_cierre']." ".$row['ts_operacion']." ".$row['id_tr']."\n";
   print($line);

   mysqli_close($conn);

   exit(0);
}


//$sql = "select nro_tarjeta from tarjetas_test where currcode_49='".$producto."' ";

$sql = "select nrtarjeta as nro_tarjeta from reporte_diaria_comer ".
       "where fecha_tr='".$date_from."' and tipo_trans='CARGA MENSUAL'";


$res = mysqli_query($conn, $sql) or die(mysqli_error($conn));

while ($tarj = mysqli_fetch_assoc($res))
{
        $row =check_saldo($conn, $tarj['nro_tarjeta'], $producto, $date_from, $date_to);

	$line = $row['id_usuario']." ".$row['nro_tarjeta']." ".$row['fecha_operacion']." ".$row['cod_operacion']." ".$row['importe']." ".$row['saldo'].
                " ".$row['prod_id']." ".$row['id_cierre']." ".$row['ts_operacion']." ".$row['id_tr']."\n";
	print($line);
}

mysqli_close($conn);

?>

