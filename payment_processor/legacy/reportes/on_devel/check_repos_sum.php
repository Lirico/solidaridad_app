#!/usr/bin/php
<?php

include("../include/params.inc");
require("PHPMailer/PHPMailerAutoload.php");

function getSumFromDB_TRX($con, $fecha, $procode, $tmen)
{
   $sum = 0.0;
   $anula = "=-1";

   if ($procode > 0)
   {
      $anula=">0";
   }

   $sql = "select sum(trx.importe*prd.kgas_carga) suma from ".
          "sgas_trx trx, sgas_productos prd ".
          "where (trx.terminal_date='".$fecha."' and trx.procode='".$procode."' and trx.tipo_mensaje='".$tmen."' ".
          "and trx.anula_comprobante".$anula.") and trx.cod_moneda=prd.cod_moneda";

   //print($sql."\n");

   $res = mysqli_query($con, $sql) or die(mysqli_error($con));

   if (mysqli_num_rows($res) > 0)
   {
      $row = mysqli_fetch_assoc($res);
      $sum = $row['suma'] + 0.0;
      mysqli_free_result($res);
   } else {
     $sum=0.0;
   }

   return $sum;
}

function getCountFromDB_TRX($con, $fecha, $procode, $tmen)
{
   $num = 0;
   $anula ="=-1";

   if ($procode > 0)
   {
      $anula = ">0";
   }

   $sql = "select count(*) cantidad from sgas_trx where terminal_date='".$fecha.
          "' and procode='".$procode."' and tipo_mensaje='".$tmen."' and ".
          "anula_comprobante".$anula;

   $res = mysqli_query($con, $sql) or die(mysqli_error($con));

   if (mysqli_num_rows($res) > 0)
   {
      $row = mysqli_fetch_assoc($res);
      $num = $row['cantidad'] + 0;
      mysqli_free_result($res);
   } else {
     $num=0;
   }

   return $num;
}

function getCountFromDB_Repo($con, $fecha, $anulado)
{
   $num = 0;

   $sql = "select count(*) cantidad from reporte_diaria where fecha_tr='".$fecha."' and anulado='".$anulado."'";

   $res = mysqli_query($con, $sql) or die(mysqli_error($con));

   if (mysqli_num_rows($res) > 0)
   {
      $row = mysqli_fetch_assoc($res);
      $num = $row['cantidad'] + 0;
      mysqli_free_result($res);
   } else {
     $num = 0;
   }

   return $num;
}

function getSumFromDB_Repo($con, $fecha, $anulado)
{
  $sum = 0.0;

  $sql = "select sum(cantidad_kilo)*-1 suma from reporte_diaria where fecha_tr='".$fecha."' and anulado='".$anulado."'";

  $res = mysqli_query($con, $sql) or die(mysqli_error($con));

   if (mysqli_num_rows($res) > 0)
   {
      $row = mysqli_fetch_assoc($res);
      $sum = $row['suma'] + 0.0;
      mysqli_free_result($res);
   } else {
     $sum = 0.0;
   }

   return $sum;
}

date_default_timezone_set('America/Argentina/Buenos_Aires');
//function checkRepo($conn, $fname, $fecha)
  $conn = mysqli_connect($db_host, $user_name, $user_pass, $db_name) or die(mysqli_connect_error());

  $ayer_ma = date('Y-m');
  $ayer_d = date('d') - 1;

  if ($ayer_d < 10)
  {
        $ayer_d = "0".$ayer_d;
  }

  $ayer = $ayer_ma."-".$ayer_d;

  //$fecha=$argv[2];
   print("fecha = ".$ayer."\n");
  $fecha = $ayer;
   print("fecha = ".$fecha."\n");
  $cuerpo = "";

  $farr = file($argv[1]);
  $nfar = count($farr);

  $cnt_anul_si = 0;
  $cnt_anul_no = 0;

  $sum_anul_si = 0.0;
  $sum_anul_no = 0.0;

  for ($i=0; $i<$nfar; $i++)
  {
     $reg = explode(';', $farr[$i]);

     //print("REG[".$i."] = ".$reg[13]."\n");
     //print("CMP = ".strcmp($reg[13], "SI")."\n");

     if (strcmp(trim($reg[13]), "SI") == 0)
     {
         $cnt_anul_si = $cnt_anul_si + 1;
         $sum_anul_si = $sum_anul_si + ($reg[9]*-1);
     } else {
         $cnt_anul_no = $cnt_anul_no + 1;
         $sum_anul_no = $sum_anul_no + ($reg[9]*-1);
     }
  }

  $cuerpo = $cuerpo."Se procesa la fecha => ".$fecha."\n\n";

  print("ANUL(NO) FILE count = ".$cnt_anul_no." | ANUL(NO) FILE total = ".$sum_anul_no."\n");
  print("ANUL(SI) FILE count = ".$cnt_anul_si." | ANUL(SI) FILE total = ".$sum_anul_si."\n");

  $cuerpo = $cuerpo."ANUL(NO) FILE count = ".$cnt_anul_no." | ANUL(NO) FILE total = ".$sum_anul_no."\n";
  $cuerpo = $cuerpo."ANUL(SI) FILE count = ".$cnt_anul_si." | ANUL(SI) FILE total = ".$sum_anul_si."\n";

  $sum_repo_anul_si = getSumFromDB_Repo($conn, $fecha, "SI");
  $sum_repo_anul_no = getSumFromDB_Repo($conn, $fecha, "NO");

  $cnt_repo_anul_si = getCountFromDB_Repo($conn, $fecha, "SI");
  $cnt_repo_anul_no = getCountFromDB_Repo($conn, $fecha, "NO");

  print("ANUL(NO) REPO count = ".$cnt_repo_anul_no." | ANUL(NO) REPO total = ".$sum_repo_anul_no."\n");
  print("ANUL(SI) REPO count = ".$cnt_repo_anul_si." | ANUL(SI) REPO total = ".$sum_repo_anul_si."\n");

  $cuerpo = $cuerpo."ANUL(NO) REPO count = ".$cnt_repo_anul_no." | ANUL(NO) REPO total = ".$sum_repo_anul_no."\n";
  $cuerpo = $cuerpo."ANUL(SI) REPO count = ".$cnt_repo_anul_si." | ANUL(SI) REPO total = ".$sum_repo_anul_si."\n";

  $sum_trx_anul_si = getSumFromDB_TRX($conn, $fecha, "020000", "0200");
  $sum_trx_anul_no_p = getSumFromDB_TRX($conn, $fecha, "000000", "0200");
  $sum_trx_anul_no = $sum_trx_anul_no_p - $sum_trx_anul_si;

  $cnt_trx_anul_si = getCountFromDB_TRX($conn, $fecha, "020000", "0200");
  $cnt_trx_anul_no_p = getCountFromDB_TRX($conn, $fecha, "000000", "0200");
  $cnt_trx_anul_no = $cnt_trx_anul_no_p - $cnt_trx_anul_si;

  print("ANUL(NO) TRX count = ".$cnt_trx_anul_no." | ANUL(NO) TRX total = ".$sum_trx_anul_no."\n");
  print("ANUL(SI) TRX count = ".$cnt_trx_anul_si." | ANUL(SI) TRX total = ".$sum_trx_anul_si."\n");

  $cuerpo = $cuerpo."ANUL(NO) TRX count = ".$cnt_trx_anul_no." | ANUL(NO) TRX total = ".$sum_trx_anul_no."\n";
  $cuerpo = $cuerpo."ANUL(SI) TRX count = ".$cnt_trx_anul_si." | ANUL(SI) TRX total = ".$sum_trx_anul_si."\n\n\n";

  $chk_si=0;
  $chk_no=0;
  $ret_scr=0;

  if (  (($cnt_anul_si == $cnt_repo_anul_si) && ($cnt_repo_anul_si == $cnt_trx_anul_si) ) && 
       (($sum_anul_si == $sum_repo_anul_si) && ($sum_repo_anul_si == $sum_trx_anul_si)) )
  {
     print("CONTEO OK!!!\n");
     $cuerpo = $cuerpo."CONTEO OK!!!\n\n\n";
     $chk_si=1;
  } else {
     print("CONTEO NOK!!!\n");
     $cuerpo = $cuerpo."CONTEO NOK!!!\n\n\n";
  }

  if ( (($cnt_anul_no == $cnt_repo_anul_no) == ($cnt_repo_anul_no == $cnt_trx_anul_no)) &&
       (($sum_anul_no == $sum_repo_anul_no) == ($sum_repo_anul_no == $sum_trx_anul_no)) )
  {
     print("CANTIDADES OK!!!\n");
     $cuerpo = $cuerpo."CANTIDADES OK!!!\n\n\n";
     $chk_no=1;
  } else {
     print("CANTIDADES NOK!!!\n");
     $cuerpo = $cuerpo."CANTIDADES NOK!!!\n\n\n";
  }

  if ( ($chk_si == $chk_no) == 1)
  {
     print("VALIDACION CORRECTA!!!\n");
     $cuerpo = $cuerpo."VALIDACION CORRECTA!!!\n";
  } else {
     print("VALIDACION INCORRECTA !!!\n");
     $ret_scr=1;
     $cuerpo = $cuerpo."VALIDACION INCORRECTA !!!\n";
  }

//checkRepo($conn, $argv[1], "2018-03-03");

mysqli_close($conn);


// MANDA MAIL CON ESTADO

$mail = new PHPMailer;
$mail->CharSet = 'UTF-8';
$mail->SMTPDebug = 0;
$mail->isSMTP();

/*
$mail->Host = 'mailtdfcard.ath.cx';
$mail->Port = 25;
$mail->SMTPAuth = true;
$mail->Username = 'agenteret';
$mail->Password = 'age$%ret';
*/

$mail->Host='validador.smsmasivos.com.ar';
$mail->Port=25;
$mail->SMTPAuth = true;
$mail->Username = 'mail@mail.tdfcard.com';
$mail->Password = 'mailtdfcard441147';

$encoding = "base64";
$type = "application/text";

$mfrom = "noreply@mail.tdfcard.com";
$mfromName = "Araucaria S.A.";

//$mail->From = "avismara@araucaria.net.ar";
//$mail->FromName = 'ARAUCARIA S.A.';

$mail->From = "noreply@mail.tdfcard.com";
$mail->FromName = "Araucaria S.A.";

$mail->WordWrap = 70;
$mail->isHTML(false);

$asunto="Reporte Solidaridad: Totalizados ".$ayer;

$contenido = file_get_contents($argv[1]);
$filename = $argv[1];

$contenido = chunk_split(base64_encode($contenido));

$mail->addStringAttachment(base64_decode($contenido), $filename, $encoding, $type);

print("Enviando........ \n");

$mail->addAddress('avismara@araucaria.net.ar', "Adriano Vismara");
//$mail->addCC('equadri@araucaria.net.ar', "Ezequiel Quadri");

$mail->Subject = $asunto;
$mail->Body = $cuerpo;

echo "Antes de enviar........ ";
if(!$mail->Send()){
    echo "No se pudo enviar el Mensaje.\n";
} else{
    echo "Mensaje enviado!!\n";
}

$mail->clearCCs();
$mail->clearBCCs();
$mail->clearAddresses();
$mail->clearAttachments();

exit($ret_scr);

?>
