# -*- coding: utf-8 -*-
"""Las descripciones de una línea, en español, para el volumen de referencia.

Sólo llevan traducción los miembros que tienen una descripción en inglés: la
descripción sale del comentario en la fuente, así que si allá no hay nada,
aquí tampoco. La generación falla si aparece una descripción nueva en inglés
sin su par en español, igual que falla si un miembro se queda sin ejemplo.

Los nombres, las firmas y el código NO se traducen: son Clarion.
"""

MEMBER_DOCS_ES = {
 'EmailNetClass.Conn':          'id de la conexión abierta, 0 = cerrada',
 'EmailNetClass.Secure':        '1 en cuanto TLS está activo sobre Conn',
 'EmailNetClass.LastError':     'un código ETNet:; 0 = correcto',
 'EmailNetClass.LastWinError':  'el código de SSPI / Winsock que hay detrás',
 'EmailNetClass.Timeout':       'milisegundos; 30000 por omisión',
 'EmailNetClass.VerifyCert':    '1 = validar el certificado del servidor (por omisión)',
 'EmailNetClass.Trace':         '1 = guardar la conversación en TraceQ',
 'EmailNetClass.HidePasswords': '1 = ocultar las credenciales en el registro (por omisión)',
 'EmailNetClass.Response':      'el cuerpo de la última llamada a Http()',
 'EmailNetClass.RespCap':       'privada en espíritu; crece según haga falta',
 'EmailNetClass.Status':        'el código HTTP de la última llamada a Http()',
 'EmailNetClass.BinLen':        'longitud del valor binario que devolvió el último Sha256 / '
                                'RandomBytes / Protect / Unprotect (un STRING devuelto se '
                                'rellena con espacios al asignarlo, así que lo binario '
                                'necesita su longitud)',
 'EmailNetClass.Body':          'el cuerpo de la última respuesta',
 'EmailNetClass.Sha256':        '32 bytes en crudo',
 'EmailNetClass.Protect':       'DPAPI, para este usuario de Windows',
 'EmailNetClass.TraceText':     'la transcripción completa, separada por CRLF',

 'EmailBufClass.Need':          'hacer sitio para pExtra bytes más',
 'EmailBufClass.AddLine':       'pLine + CRLF',
 'EmailBufClass.ClearAll':      'NO se llama Clear: un miembro de clase cuya etiqueta '
                                'coincide con una intrínseca de Clarion redefine esa '
                                'intrínseca para CADA módulo que incluya este archivo, y el '
                                'siguiente CLEAR(UnaVariable) en cualquier parte de la '
                                'aplicación deja de compilar con "No matching prototype '
                                'available". La misma trampa que BEGIN y RESET.',
 'EmailBufClass.Value':         'todo el contenido, como STRING',

 'EmailMsgClass.CharSet':       'ETChs:Utf8 (por omisión) o ETChs:Ansi',
 'EmailMsgClass.ReadReceipt':   '1 = pedir acuse de lectura',
 'EmailMsgClass.MessageId':     'se genera si se deja vacío',
 'EmailMsgClass.TzMinutes':     'minutos al este de UTC para el encabezado Date:',
 'EmailMsgClass.Mime':          'lo que produjo Build()',
 'EmailMsgClass.MaxSize':       'negarse a construir por encima de esto (0 = sin límite)',
 'EmailMsgClass.Validate':      '1 = listo para enviar',
 'EmailMsgClass.Build':         'devuelve la longitud del MIME, <0 si hubo error',
 'EmailMsgClass.RecipientList': '"a@b.com, c@d.com" para un encabezado',
 'EmailMsgClass.EnvelopeCount': 'todos los To + Cc + Bcc, para el RCPT TO',
 'EmailMsgClass.Base64Url':     'RFC 4648 sección 5: -_ y sin relleno',
 'EmailMsgClass.Utf8':          'Windows-1252 -> UTF-8',
 'EmailMsgClass.EncodeHeader':  'RFC 2047, sólo si hace falta',
 'EmailMsgClass.NeedsEncoding': 'reglas de encabezado: cualquier carácter de control cuenta',
 'EmailMsgClass.JsonString':    'escapado y entre comillas, para los transportes REST',

 'EmailOAuthClass.Net':         'prestado de EmailToClass, no es suyo',
 'EmailOAuthClass.Msg':         'objeto codificador prestado, no es suyo',
 'EmailOAuthClass.LastAuthUrl': 'la dirección de consentimiento que realmente se abrió: '
                                'péguela a mano en un navegador cuando falle un inicio de '
                                'sesión y el proveedor dirá exactamente qué objeta',
 'EmailOAuthClass.RedirectPort': '0 = pedirle a Windows un puerto libre',
 'EmailOAuthClass.RedirectHost': 'vacío = 127.0.0.1 para Google, localhost para Microsoft. '
                                 'Tiene que coincidir con lo que registró, y los dos '
                                 'proveedores documentan uno distinto; el escucha responde '
                                 'en los dos',
 'EmailOAuthClass.WaitSeconds': 'cuánto tiempo dejar abierto el navegador',
 'EmailOAuthClass.SetErr':      'lo registra Y contesta',

 'EmailToClass.Msg':            'el mensaje propio de la clase que usa SendSimple',
 'EmailToClass.Language':       'ETLng:English / ETLng:Spanish',
 'EmailToClass.Silent':         '1 = no mostrar nunca un cuadro de mensaje',
 'EmailToClass.Trace':          '1 = conservar la transcripción de la conversación',
 'EmailToClass.IniFile':        'el almacén por omisión de LoadAccount / SaveAccount',
 'EmailToClass.LastServerReply': 'lo último que dijo el servidor',
 'EmailToClass.Capabilities':   'lo que reportó el EHLO',
 'EmailToClass.SetErr':         'lo registra Y contesta 1 = funcionó / 0 = falló, para que un '
                                'método pueda terminar con RETURN SELF.SetErr(...)',
 'EmailToClass.EhloDomain':     'el nombre con el que nos anunciamos en el EHLO',
}

FIELD_DOCS_ES = {
 'EmailAccountGroup.Name':         'la etiqueta con la que se guarda esta cuenta',
 'EmailAccountGroup.Transport':    'ETTrn:...',
 'EmailAccountGroup.Provider':     'ETPrv:...',
 'EmailAccountGroup.Security':     'ETSec:...',
 'EmailAccountGroup.AuthMode':     'ETAuth:...',
 'EmailAccountGroup.Password':     'o la contraseña de aplicación',
 'EmailAccountGroup.ClientId':     'OAuth2: su aplicación registrada',
 'EmailAccountGroup.ClientSecret': 'vacío para un cliente público o de escritorio',
 'EmailAccountGroup.TenantId':     'Microsoft: common, organizations o un GUID',
 'EmailAccountGroup.ApiDomain':    'el dominio de envío de Mailgun',
 'EmailAccountGroup.Timeout':      'milisegundos; 0 = 30000',
 'EmailAccountGroup.VerifyCert':   '1 = comprobar el certificado del servidor (por omisión)',

 'EmailAddrQueue.Kind':            'ETAddr:To / ETAddr:Cc / ETAddr:Bcc',
 'EmailAttachQueue.FileName':      'ruta completa; vacío cuando se usa Data',
 'EmailAttachQueue.ShownAs':       'el nombre que ve el destinatario',
 'EmailAttachQueue.ContentType':   'se deduce de la extensión si se deja vacío',
 'EmailAttachQueue.ContentId':     'con valor = incrustado, referido como <img src="cid:...">',
 'EmailAttachQueue.Data':          'contenido en memoria; NULL cuando se usa FileName',
}

EQUATE_NOTES_ES = {
 'ETNet:MaxLine':    'la línea de protocolo más larga que vamos a leer',
 'ETChs:Utf8':       'convertir desde Windows-1252 (por omisión)',
 'ETChs:Ansi':       'mandar los bytes tal cual, etiquetados windows-1252',
 'ETPrv:Custom':     'usted pone el servidor y el puerto',
 'ETPrv:Outlook':    'outlook.com / hotmail.com / live.com',
 'ETPrv:Office365':  'una cuenta de trabajo o escuela de Microsoft 365',
 'ETSec:None':       'texto plano, puerto 25 - sólo para un relay local',
 'ETSec:StartTls':   'conectar en plano y elevar con STARTTLS (587)',
 'ETSec:Tls':        'TLS desde el primer byte (465)',
 'ETAuth:Login':     'AUTH LOGIN  - usuario y contraseña, en base64',
 'ETAuth:Plain':     'AUTH PLAIN  - un solo bloque base64',
 'ETAuth:XOAuth2':   'AUTH XOAUTH2 - un token de acceso OAuth2',
}
