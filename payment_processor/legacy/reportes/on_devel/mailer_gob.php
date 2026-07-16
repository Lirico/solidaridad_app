<?php
include("include/params.inc");
require("PHPMailer/PHPMailerAutoload.php");

function checkRepo($fname)
{
  $ret = 0;

  $farr = file($fname);
  $nfar = count($farr);

  $cnt_anul_si = 0;
  $cnt_anul_no = 0;

  $sum_anul_si = 0.0;
  $sum_anul_no = 0.0;

  for ($i=0; $i<$nfar; $i++)
  {
     $reg = explode(';', $farr[$i]);
     if ($reg[13] == "SI")
     {
         $cnt_anul_si = $cnt_anul_si + 1;
         $sum_anul_si = $sum_anul_si + $reg[9];
     } else {
         $cnt_anul_no = $cnt_anul_no + 1;
         $sum_anul_no = $sum_anul_no + $reg[9];
     }
  }

  return $ret;
}


$mail = new PHPMailer;
$mail->CharSet = 'UTF-8';
$mail->SMTPDebug = 2;
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

$ayer_ma = date('Y-m');
$ayer_d = date('d') - 1;

if ($ayer_d < 10)
{
	$ayer_d = "0".$ayer_d;
}

$ayer = $ayer_ma."-".$ayer_d;

$asunto="Reporte Solidaridad Gas - Dia ".$ayer;
$cuerpo = "Se adjunta reporte CSV con las transacciones.\n\n\n\n--\nAraucaria S.A.\n";

$contenido = file_get_contents($argv[1]);
$filename = $argv[1];

$contenido = chunk_split(base64_encode($contenido));

$mail->addStringAttachment(base64_decode($contenido), $filename, $encoding, $type);

print("Enviando........ \n");

$mail->addAddress('subsidioproveedores@tierradelfuego.gob.ar', "PROVEEDORES");
$mail->addCC('creynoso@tierradelfuego.gob.ar', "Carolina Reynoso");

// agregados por Lucas Martinez 14/11/2016
$mail->addCC('mavenegas@tierradelfuego.gob.ar', "mavenegas");
$mail->addCC('plucas@tierradelfuego.gob.ar', "Pablo Lucas");

// Sergio Andrada 14/01/2019
//$mail->addCC('sandrada@tierradelfuego.gov.ar', "Sergio Andrada");

// Marilina Gallardo 06/09/019
$mail->addCC('mgallardo@tierradelfuego.gob.ar', "Marilina Gallardo");

// SOLO PARA TEST
//$mail->addAddress('aivismara@gmail.com', "PROVEEDORES");

// COPIAS TESTIGO
$mail->addCC('avismara@araucaria.net.ar', "Adriano Vismara");
$mail->addCC('equadri@araucaria.net.ar', "Ezequiel Quadri");
$mail->addCC('germannieto@tdfcard.com', "German Nieto");
$mail->addCC('svetlis@tdfcard.com', "Silvia Etlis");
$mail->addCC('arielgualla@tdfcard.com', "Ariel Gualla");

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

?>
