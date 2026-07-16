<?php

require("PHPMailer/PHPMailerAutoload.php");


$mail = new PHPMailer;
$mail->CharSet = 'UTF-8';
$mail->SMTPDebug = 0;
$mail->isSMTP();
//$mail->Host = 'validador.smsmasivos.com.ar';
$mail->Host = 'mailtdfcard.ath.cx';

$mail->Port = 25;
$mail->SMTPAuth = true;
//$mail->Username = 'mail@mail.tdfcard.com';
//$mail->Password = 'mailtdfcard441147';

$mail->Username = 'agenteret';
$mail->Password = 'age$%ret';

$encoding = "base64";
$type = "application/text";

$mail->From = "avismara@araucaria.net.ar";
$mail->FromName = 'ARAUCARIA S.A.';

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

$mail->addAddress('administracion@gasaustral.com.ar', 'Administracion Gas Austral');
$mail->addAddress('gerencia@gasaustral.com.ar', 'Gerencia');
$mail->addCC('jgatica@gasaustral.com.ar', 'JGatica');
$mail->addCC('emilio82mza@hotmail.com', 'Emilio');
$mail->addCC('facturacion@gasaustral.com.ar', 'Facturacion Gas Austral');

$mail->addCC('natarambu@tierradelfuego.gov.ar', 'Natalia Aramburu');
$mail->addCC('prusso@tierradelfuego.gov.ar', 'Pablo MF. Russo');

$mail->addCC('equadri@araucaria.net.ar', 'Ezequiel Quadri');
$mail->addCC('avismara@araucaria.net.ar', 'Adriano Vismara');

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
