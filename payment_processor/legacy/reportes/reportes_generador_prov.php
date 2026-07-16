<?php
include("include/params.inc");

function CreateTemporal_TRX($con, $fecha)
{
	$sql = "create table kigsolidario2.sgas_tmp (select * from kigsolidario2.sgas_trx where terminal_date='".$fecha."' and procode='020000');";

	print("CreateTemporal_TRX() MYSQL: ".$sql."\n");

	$qret = mysqli_multi_query($con, $sql);

	if (!$qret)
	{
		
		$sql = "drop table kigsolidario2.sgas_tmp;create table kigsolidario2.sgas_tmp (select * from kigsolidario2.sgas_trx where terminal_date='".$fecha."' and procode='020000');";
		$qret = mysqli_multi_query($con, $sql);
	}
	
	return $qret;
}

function RepoGeneradorComer($con, $periodo, $fecha)
{
	if (!CreateTemporal_TRX($con, $fecha))
	{
		print("RepoGeneradorComer() ERROR #1: No se puede crear tabla temporal.\n");
		print("RepoGeneradorComer() ERROR #2: ".mysqli_error($con)."\n");
		return false;
	}

	// reporte_diaria_comer

	$sql = "insert into kigsolidario2.reporte_diaria_comer (ciudad,barrio,id_tr,fecha_tr,hora_tr,apellido_nombre,nro_doc, ".
"periodo,prod_id,cantidad_kilo,codigo_proveedor,ubicacion_entrega,tipo_trans,anulado, ".
"nrtarjeta, domicilio, cod_comer, termid, lote, cupon, prd_com, importe, auth_code, trxid ) (".
"select s1.localidad, s1.barrio, concat(trim(s1.cod_comercio), s1.terminalid, s1.lote, s1.numero_comprobante) as num_tr, ".
"s1.terminal_date, s1.terminal_time, ".
"s1.apellido_nombre, s1.id_usuario, s1.periodo, s1.tipo_plan, (s1.importe*-1) importe, s1.razon_social, s1.modelo, s1.cid, s1.marca_anulado ".
",s1.tarjeta, s1.direccion, s1.cod_comercio, s1.terminalid, s1.lote, s1.numero_comprobante, s1.prodid_com, s1.envace, s1.auth, s1.trunid ".
"from (select  usr.localidad, usr.barrio, trx.cod_comercio, trx.terminalid, ".
"if(trx.lote<10, concat('0', cast(trx.lote as char(10) ) ), cast(trx.lote as char(10)) ) as lote, ".
"if(trx.numero_comprobante<10, concat('0', cast(trx.numero_comprobante as char(10) ) ), cast(trx.numero_comprobante as char(10)) ) as numero_comprobante, ".
"trx.terminal_date, trx.terminal_time, usr.apellido_nombre,  usr.id_usuario, DATE_FORMAT(CURRENT_DATE(), '%y-%m-01')as periodo,  ".
"prd.id_normal tipo_plan, (trx.importe*prd.kgas_carga) importe, ".
"comer.razon_social, if(tr.modelo='GPRS', 'C', 'O') modelo, ".
"if ((trx.tipo_mensaje='0200' and trx.procode='000000'), 'DESCARGA', ".
"if ((trx.tipo_mensaje='0200' and trx.procode='200000'), 'DEVOL', ".
"if ((trx.tipo_mensaje='0200' and trx.procode='200001'), 'CARGA MENSUAL', 'CIERRE' ))) cid, ".
"kigsolidario2.checkAnulacion2(trx.terminalid, trx.nro_tarjeta, trx.terminal_date, trx.numero_comprobante, trx.lote) marca_anulado, ".
"concat('0', cast(prd.id_normal as char(1)), '00', if(prd.id_normal=3, '90', cast(prd.kgas_carga as char(2))) ) prodid_com, ".
"trx.codigo_autorizacion auth, trx.id trunid, trx.importe envace, usr.nro_tarjeta tarjeta, usr.domicilio direccion ".
"from kigsolidario2.sgas_trx trx, kigsolidario2.sgas_usuario usr, kigsolidario2.sgas_comercio comer, kigsolidario2.terminales tr, kigsolidario2.sgas_productos prd ".
"where trx.nro_tarjeta=usr.nro_tarjeta ".
"and trx.cod_comercio=comer.cod_comercio and trx.terminalid=tr.codigo_terminales and (trx.nro_tarjeta!='6063007014999900') and trx.procode!='020000' ".
"and trx.tipo_mensaje!='0400' and trx.cod_moneda = prd.cod_moneda order by trx.lote, trx.numero_comprobante ) s1 ".
"WHERE s1.terminal_date='".$fecha."' ".
"); drop table kigsolidario2.sgas_tmp;";
	

	print("RepoGeneradorComer() MySQL: ".$sql."\n");

	$qret = mysqli_multi_query($con, $sql);

	return $qret;
}

// MAIN FUNCTION

$conn = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

$per=date('Y-m')."-01";

$ayer_ma = date('Y-m');
$ayer_d = date('d') - 1;

if ($ayer_d < 10)
{
	$ayer_d = "0".$ayer_d;
}

$ayer = $ayer_ma."-".$ayer_d;

print("AYER: ".$ayer."\n");

if (!RepoGeneradorComer($conn, $per, $ayer))
{
	print("RepoGeneradorComer MAIN() ERROR #1: No se puede crear el reporte.\n");
	print("RepoGeneradorComer MAIN() ERROR #2: ".mysqli_error($conn)."\n");
	return false;
}

mysqli_close($conn);

?>
