<?php

function checkExist($conn, $nro_doc)
{
	$sql = "SELECT situacion FROM sgas_usuario WHERE nro_doc='".$nro_doc."'";

	$res = mysqli_query($conn, $sql) or die(mysqli_error($conn));
	if (mysqli_num_rows($res)==0)
	{
		mysqli_free_result($res);
		return -1;
	} else{
		$row = mysqli_fetch_array($res);
		if ($row[0] == 'V')
		{
			mysqli_free_result($res);
			return 0;
		} else {
			mysqli_free_result($res);
			return -1;
		}
	}
}

function checkCardExist($conn, $cardn)
{
	$sql = "SELECT situacion FROM sgas_usuario WHERE nro_tarjeta='".$cardn."'";

	$res = mysqli_query($conn, $sql) or die(mysqli_error($conn));
	if (mysqli_num_rows($res)==0)
	{
		mysqli_free_result($res);
		return -1;
	} else{
		$row = mysqli_fetch_array($res);
		if ($row[0] == 'V')
		{
			mysqli_free_result($res);
			return 0;
		} else {
			mysqli_free_result($res);
			return 0;
		}
	}
}

function calVigencia()
{
	$retarr = array();

	$mes = date('m');
	$anio = date('Y');

	$str_mes = "";

	if (($mes+1) < 10)
	{
		$str_mes="0".($mes+1);
	} else {
		$str_mes=($mes+1);
	}

	$vig_desde = $anio."-".$str_mes."-01";

	if ($mes < 10)
	{
		$str_mes=$mes;
	} else {
		$str_mes=$mes;
	}

	$vig_hasta = ($anio+5)."-".$str_mes."-30";

	$retarr[0] = $vig_desde;
	$retarr[1] = $vig_hasta;

	return $retarr;
}

function call2VD($conn, $addvd)
{
	$sql_call = "SELECT ".$addvd." as card";
	$res = mysqli_query($conn, $sql_call) or die(mysqli_error($conn));
	$arr = mysqli_fetch_assoc($res);

	$ret = $arr['card'];

	mysqli_free_result($res);

	return $ret;
}

function NumCtaBySuc($conn, $suc)
{
	if ($suc == '01')
	{
		$sql = "select card_client_number num_cta from sgas_internal_index";
	}

	if ($suc == '02')
	{
		$sql = "select card_client_number2 num_cta from sgas_internal_index";
	}

	$res = mysqli_query($conn, $sql) or die(mysqli_error($conn));
	$arr = mysqli_fetch_assoc($res);

	$ret = $arr['num_cta'];

	mysqli_free_result($res);

	return $ret;
}

function UpdateNumCtaBySuc($conn, $suc, $nuser)
{
	if ($suc == '01')
	{
		$sql = "update sgas_internal_index set card_client_number=".$nuser;
	}

	if ($suc == '02')
	{
		$sql = "update sgas_internal_index set card_client_number2=".$nuser;
	}

	mysqli_query($conn, $sql) or die(mysqli_error($conn));
}

?>
