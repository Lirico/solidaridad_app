#!/usr/bin/php
<?php
include("./include/params.inc");
include("./include/varias.inc");

function genera_cvv($ndoc)
{
  $ret_cvv = 0;
  $time_var=time();

  print("genera_cvv() -> TIMEVAR = ".$time_var."\n");
  print("genera_cvv() -> DOC = ".$ndoc."\n");

  $seed = $ndoc + $time_var;

  print("genera_cvv() -> SEED = ".$seed."\n");

  srand($seed);
  $sr = rand();

  print("genera_cvv() -> SRAND = ".$sr."\n");

  $sr_len = strlen($sr);
  $ret_cvv = substr($sr, -3);

  print("genera_cvv) -> RET_CVV = ".$ret_cvv."\n");
  return $ret_cvv;
}



// MAIN

$con = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

$sql= "SELECT LTRIM(RTRIM(nombre_apellido)) nombre_apellido, LTRIM(RTRIM(tipo_doc)) tipo_doc, ".
      "cast(LTRIM(RTRIM(nro_doc)) as unsigned) nro_doc, ".
       "DATE_FORMAT(STR_TO_DATE(LTRIM(RTRIM(fec_nac)), '%d/%m/%Y'), '%Y-%m-%d') fec_nac , LTRIM(RTRIM(domicilio)) domicilio, LTRIM(RTRIM(provincia)) provincia, ".
       "LTRIM(RTRIM(localidad)) localidad, LTRIM(RTRIM(barrio)) barrio, LTRIM(RTRIM(cod_postal)) cod_postal, LTRIM(RTRIM(cod_operacion)) cod_operacion ".
       "FROM sgas_usuario_load ";

$result = mysqli_query($con, $sql) or die(mysqli_error($con));

while ($row = mysqli_fetch_assoc($result))
{
	//
	//	, fecha_emision CURRENT_DATE()
	//	, vigencia_desde CURRENT_DATE() + 1 mes (primer dia)
	//	, vigencia_hasta + 2 años - 1 mes (ultimo dia)
	//	, fecha_alta CURRENT_DATE()
	//
	//	digito verificador = 2 MOD-TDF
	//

	$bin = "6063007";
	$dv = 2;    // add_vd(concat('6063007',suc,nro_cta,'0'),7,dig_verificador)
	$sucursal="01";

	if ($row['cod_operacion'] != 'A')
	{
		if ($row['cod_operacion'] == 'B')
		{
			print("PROCESANDO BAJA: NRO_DOC ".$row['nro_doc']."\n");

			$sql_oper = "UPDATE sgas_usuario SET situacion='P', fecha_situacion=CURRENT_DATE() WHERE nro_doc='".$row['nro_doc']."'";
			mysqli_query($con, $sql_oper) or die(mysqli_error($con));
		}

		if ($row['cod_operacion'] == 'M')
		{
                        print("PROCESANDO MODIFICACION: NRO_DOC ".$row['nro_doc']."\n");
 			//print("Se ha modificado: ".$row['nro_doc']."\n");
			$sql_oper = "UPDATE sgas_usuario SET domicilio='".$row['domicilio']."', provincia='".$row['provincia'].
                                    "', localidad='".$row['localidad']."', barrio='".$row['barrio'].
                                    "', situacion='V', fecha_situacion=CURRENT_DATE() ".
                                    "WHERE nro_doc='".$row['nro_doc']."'";

                        mysqli_query($con, $sql_oper) or die(mysqli_error($con));
                }

	} else {
		if (checkExist($con, $row['nro_doc']) == -1)
		{
			$vig_desde = "";
			$vig_hasta = "";

			$vigArray = calVigencia();
			$vig_desde = $vigArray[0];
			$vig_hasta = $vigArray[1];

			print("Vigencia DESDE: ".$vig_desde."\n");
			print("Vigencia HASTA: ".$vig_hasta."\n");

			if ( ($row['cod_postal'] == '9410') || ($row['cod_postal'] == '9412') )
			{
				$sucursal = "01";

				$nro_usuario = NumCtaBySuc($con, $sucursal);
				print("NRO Tarjeta: ".$nro_usuario." - ".$sucursal."\n");

				$card_num = call2VD($con, "add_vd('".$bin.$sucursal.$nro_usuario."0', 7, 2)");

				$cex = checkCardExist($con, $card_num);

				while ($cex != -1)
				{
					$nro_usuario++;

					UpdateNumCtaBySuc($con, $sucursal, $nro_usuario);

					$nro_usuario = NumCtaBySuc($con, $sucursal);

					print("NRO Tarjeta (while): ".$nro_usuario."\n");

					$card_num = call2VD($con, "add_vd('".$bin.$sucursal.$nro_usuario."0', 7, 2)");

					$cex = checkCardExist($con, $card_num);
				}

			}

			if ($row['cod_postal'] == '9420')
			{
				$sucursal = "02";

				$nro_usuario = NumCtaBySuc($con, $sucursal);
				print("NRO Tarjeta: ".$nro_usuario." - ".$sucursal."\n");

				$card_num = call2VD($con, "add_vd('".$bin.$sucursal.$nro_usuario."0', 7, 2)");

				$cex = checkCardExist($con, $card_num);

				while ($cex != -1)
				{
					$nro_usuario++;

					UpdateNumCtaBySuc($con, $sucursal, $nro_usuario);

					$nro_usuario = NumCtaBySuc($con, $sucursal);

					print("NRO Tarjeta (while): ".$nro_usuario."\n");

					$card_num = call2VD($con, "add_vd('".$bin.$sucursal.$nro_usuario."0', 7, 2)");

					$cex = checkCardExist($con, $card_num);
				}
			}

                        $rcvv = genera_cvv($row['nro_doc']);

			$sql_ins = "INSERT INTO sgas_usuario(sucursal,num_cta, id_usuario,nro_tarjeta,situacion,fecha_situacion,".
                                   "dig_verificador,apellido_nombre,domicilio,provincia,localidad,barrio,cod_postal,tipo_doc,nro_doc,".
                                   "fecha_nac,fecha_emision,vigencia_desde,vigencia_hasta,fecha_alta, cvv_actual, cvv_renovacion)".
                                   " VALUES ('".$sucursal."', '".$nro_usuario."','".$row['nro_doc']."',".
    		                   "'".$card_num."'".
    		                   ",'V','".date('Y-m-d')."', 2,'".addslashes($row['nombre_apellido']).
    		                   "','".addslashes($row['domicilio'])."','".
    		                   addslashes($row['provincia']).
    		                   "','".addslashes($row['localidad'])."','".addslashes($row['barrio'])."','".
                                   $row['cod_postal']."','".$row['tipo_doc']."','".
    		                   $row['nro_doc']."', CURRENT_DATE(),".
    		                   "CURRENT_DATE(),".     // fecha emision
			           "'".$vig_desde."',".   // vigencia_desde
			           "'".$vig_hasta."',".   // vigencia_hasta
			           "CURRENT_DATE(), ".     // fecha_alta
			           "'".$rcvv."', '".$rcvv."')";

			print("SQL: ".$sql_ins."\n");

			mysqli_query($con, $sql_ins) or die(mysqli_error($con));

                        // generamos ceros para todos los productos de manera tal que permita
                        // las cargas en caliente.

			// 993
			$sql_cta = "INSERT INTO sgas_usuario_cta(id_usuario,nro_tarjeta,fecha_operacion,cod_operacion,importe,saldo,prod_id)".
                                   "VALUES('".$row['nro_doc']."', add_vd('".$bin.$sucursal.$nro_usuario.
                                   "0', 7, 2), CURRENT_DATE(), 1, 0.0, 0.0, '993')";

			mysqli_query($con, $sql_cta) or die(mysqli_error($con));

			// 994
                        $sql_cta = "INSERT INTO sgas_usuario_cta(id_usuario,nro_tarjeta,fecha_operacion,cod_operacion,importe,saldo,prod_id)". 
                                   "VALUES('".$row['nro_doc']."', add_vd('".$bin.$sucursal.$nro_usuario.
                                   "0', 7, 2), CURRENT_DATE(), 1, 0.0, 0.0, '994')";

                        mysqli_query($con, $sql_cta) or die(mysqli_error($con));

			// 995
			$sql_cta = "INSERT INTO sgas_usuario_cta(id_usuario,nro_tarjeta,fecha_operacion,cod_operacion,importe,saldo,prod_id)". 
                                   "VALUES('".$row['nro_doc']."', add_vd('".$bin.$sucursal.$nro_usuario.
                                   "0', 7, 2), CURRENT_DATE(), 1, 0.0, 0.0, '995')";

                        mysqli_query($con, $sql_cta) or die(mysqli_error($con));

			// 996
                        $sql_cta = "INSERT INTO sgas_usuario_cta(id_usuario,nro_tarjeta,fecha_operacion,cod_operacion,importe,saldo,prod_id)". 
                                   "VALUES('".$row['nro_doc']."', add_vd('".$bin.$sucursal.$nro_usuario.
                                   "0', 7, 2), CURRENT_DATE(), 1, 0.0, 0.0, '996')";

                        mysqli_query($con, $sql_cta) or die(mysqli_error($con));

			// 997
			$sql_cta = "INSERT INTO sgas_usuario_cta(id_usuario,nro_tarjeta,fecha_operacion,cod_operacion,importe,saldo,prod_id)". 
                                   "VALUES('".$row['nro_doc']."', add_vd('".$bin.$sucursal.$nro_usuario.
                                   "0', 7, 2), CURRENT_DATE(), 1, 0.0, 0.0, '997')";

                        mysqli_query($con, $sql_cta) or die(mysqli_error($con));

			//print("SQL: ".$sql_cta."\n");

			print("FINAL NRO Tarjeta: ".$nro_usuario."\n");
			$nro_usuario++;
			UpdateNumCtaBySuc($con, $sucursal, $nro_usuario);

		} else {
			print("ERROR: DNI:".$row['nro_doc']." AUN ACTIVO.\n");
		}
	}
}

mysqli_free_result($result);
mysqli_close($con);

?>
