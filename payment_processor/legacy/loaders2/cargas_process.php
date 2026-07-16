<?php
include("include/params.inc");

function getProdCodMoneda($conn, $prod_id)
{
	$cod_moneda = "";

	$sql = "SELECT cod_moneda FROM sgas_productos WHERE id_normal='".$prod_id."'";

	$res = mysqli_query($conn, $sql) or die(mysqli_error($conn));
	if (mysqli_num_rows($res)==0)
	{
		mysqli_free_result($res);
		return -1;
	} else{
		$row = mysqli_fetch_array($res);
		$cod_moneda = $row[0];
	}

	return $cod_moneda;
}

$con = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

$sql = "SELECT CAST(cld.monto as DECIMAL(10, 2)) amount, cld.dni, uld.nro_tarjeta, cast(cld.prod_id as unsigned) prod_id  FROM sgas_cantidades_load cld, ".
	   "sgas_usuario uld WHERE RTRIM(LTRIM(cld.dni)) = LTRIM(RTRIM(uld.nro_doc)) and uld.situacion='S'";

$res = mysqli_query($con, $sql) or die(mysqli_error($con));

if (mysqli_num_rows($res) > 0)
{
	while ($row = mysqli_fetch_assoc($res))
	{
		$cmoneda = getProdCodMoneda($con, $row['prod_id']);

		print("ANTES DNI: ".$row['dni'].", Nro. Tarjeta: ".$row['amount']."; Moneda = ".$row['prod_id']."\n");

		$sql_ins = "INSERT INTO sgas_usuario_cta(id_usuario,nro_tarjeta,fecha_operacion,cod_operacion,importe,saldo, prod_id) VALUES(".
		"'".$row['dni']."','".$row['nro_tarjeta']."', '2015-11-01',1,".$row['amount'].",".$row['amount'].", '".$cmoneda."' )";

		mysqli_query($con, $sql_ins) or die(mysqli_error($con));

		print("DESPUES DNI: ".$row['dni'].", Nro. Tarjeta: ".$row['amount']."; Moneda = ".$cmoneda."\n");
	}
} else {
	print("ERROR EN ASIGNACION: DNI = ".$row['dni']."\n");
}

mysqli_free_result($res);
mysqli_close($con);

?>
