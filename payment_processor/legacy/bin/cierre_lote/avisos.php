#!/usr/bin/php
<?php

require("PHPMailer/PHPMailerAutoload.php");


$mail = new PHPMailer;
$mail->CharSet = 'UTF-8';
$mail->SMTPDebug = 1;
$mail->isSMTP();
//$mail->Host = 'mailtdfcard.ath.cx';
$mail->Host = '192.168.1.233';
$mail->Port = 25;
$mail->SMTPAuth = true;
$mail->Username = 'agenteret';
$mail->Password = 'age$%ret';

$encoding = "base64";
$type = "application/text";

$mail->From = "agenteret@tdfcard.com";
$mail->FromName = 'TDF S.A.';

$mail->WordWrap = 70;
$mail->isHTML(false);

$asunto="Cierre de Lotes";
$cuerpo = "Aviso de cierre de lotes.\n";

$contenido = file_get_contents("./screenlog.0");
$filename = "screenlog.0";

$contenido = chunk_split(base64_encode($contenido));

$mail->addStringAttachment(base64_decode($contenido), $filename, $encoding, $type);

print("Enviando..... avismara@araucaria.net.ar... \n");

$mail->addAddress('avismara@araucaria.net.ar', "Adriano");
$mail->addAddress('aivismara@gmail.com', "Adriano");
$mail->addAddress('equadri@araucaria.net.ar', "Ezequiel");

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
