import Foundation

enum L {
    private static let languages = ["en", "de", "fr", "es", "it", "nl"]

    private static let index: Int = {
        let preferred = (Bundle.main.preferredLocalizations + Locale.preferredLanguages)
            .map { String($0.prefix(2)).lowercased() }
        for code in preferred {
            if let i = languages.firstIndex(of: code) { return i }
        }
        return 0
    }()

    static func s(_ key: String) -> String {
        guard let row = table[key] else { return key }
        return row.indices.contains(index) ? row[index] : row[0]
    }

    static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: s(key), locale: Locale(identifier: languages[index]), arguments: args)
    }

    private static let table: [String: [String]] = [
        "reason.off": ["turned off", "ausgeschaltet", "désactivé", "desactivado", "disattivato", "uitgeschakeld"],
        "reason.noFace": ["no face saved", "kein Gesicht gespeichert", "aucun visage enregistré", "ninguna cara guardada", "nessun volto salvato", "geen gezicht opgeslagen"],
        "reason.noPassword": ["no password saved", "kein Passwort gespeichert", "aucun mot de passe enregistré", "ninguna contraseña guardada", "nessuna password salvata", "geen wachtwoord opgeslagen"],
        "reason.camera": ["camera not allowed", "Kamera nicht erlaubt", "caméra non autorisée", "cámara no permitida", "fotocamera non consentita", "camera niet toegestaan"],
        "reason.accessibility": ["Accessibility missing", "Bedienungshilfen fehlen", "Accessibilité manquante", "Falta Accesibilidad", "Manca Accessibilità", "Toegankelijkheid ontbreekt"],

        "note.lockedOff": ["Locked · Face Unlock is off", "Gesperrt · Face Unlock ist ausgeschaltet", "Verrouillé · Face Unlock est désactivé", "Bloqueado · Face Unlock está desactivado", "Bloccato · Face Unlock è disattivato", "Vergrendeld · Face Unlock staat uit"],
        "note.lockedNotReady": ["Locked, not ready: %@", "Gesperrt, aber nicht bereit: %@", "Verrouillé, pas prêt : %@", "Bloqueado, no está listo: %@", "Bloccato, non pronto: %@", "Vergrendeld, niet klaar: %@"],
        "note.waitingKey": ["Locked · waiting for a key press", "Gesperrt · wartet auf Tastendruck", "Verrouillé · en attente d’une touche", "Bloqueado · esperando una tecla", "Bloccato · in attesa di un tasto", "Vergrendeld · wacht op een toets"],
        "note.waitingWake": ["Locked · Input Monitoring missing, starts only when the display wakes", "Gesperrt · Eingabeüberwachung fehlt, startet nur beim Aufwachen des Displays", "Verrouillé · Surveillance de l’entrée manquante, démarre seulement au réveil de l’écran", "Bloqueado · falta Monitorización de entrada, solo empieza al activarse la pantalla", "Bloccato · manca Monitoraggio input, parte solo al risveglio dello schermo", "Vergrendeld · Invoermonitoring ontbreekt, start alleen als het scherm ontwaakt"],
        "note.trigger": ["%@ · scanning", "%@ · scanne", "%@ · analyse", "%@ · escaneando", "%@ · scansione", "%@ · scannen"],
        "why.key": ["Key pressed", "Taste gedrückt", "Touche pressée", "Tecla pulsada", "Tasto premuto", "Toets ingedrukt"],
        "why.wake": ["Display woke", "Display aufgewacht", "Écran réveillé", "Pantalla activada", "Schermo risvegliato", "Scherm ontwaakt"],
        "why.saver": ["Screen saver ended", "Bildschirmschoner beendet", "Économiseur d’écran terminé", "Salvapantallas terminado", "Salvaschermo terminato", "Schermbeveiliging beëindigd"],
        "note.unlocked": ["Unlocked with Face Unlock", "Mit Face Unlock entsperrt", "Déverrouillé avec Face Unlock", "Desbloqueado con Face Unlock", "Sbloccato con Face Unlock", "Ontgrendeld met Face Unlock"],
        "note.noCamera": ["No camera found", "Keine Kamera gefunden", "Aucune caméra trouvée", "No se encontró ninguna cámara", "Nessuna fotocamera trovata", "Geen camera gevonden"],
        "note.timeout": ["Not recognized · waiting for the next key press", "Nicht erkannt · wartet auf nächsten Tastendruck", "Non reconnu · en attente de la prochaine touche", "No reconocido · esperando la próxima tecla", "Non riconosciuto · in attesa del prossimo tasto", "Niet herkend · wacht op de volgende toets"],

        "lock.pressKey": ["Press a key to unlock", "Taste drücken zum Entsperren", "Appuyez sur une touche pour déverrouiller", "Pulsa una tecla para desbloquear", "Premi un tasto per sbloccare", "Druk op een toets om te ontgrendelen"],
        "lock.timeout": ["Not recognized · press a key", "Nicht erkannt · Taste drücken", "Non reconnu · appuyez sur une touche", "No reconocido · pulsa una tecla", "Non riconosciuto · premi un tasto", "Niet herkend · druk op een toets"],
        "lock.key": ["Key", "Taste", "Touche", "Tecla", "Tasto", "Toets"],
        "lock.blocked": ["Face Unlock: %@", "Face Unlock: %@", "Face Unlock : %@", "Face Unlock: %@", "Face Unlock: %@", "Face Unlock: %@"],
        "lock.searching": ["Looking for your face …", "Suche dein Gesicht …", "Recherche de votre visage …", "Buscando tu cara …", "Cerco il tuo volto …", "Zoekt je gezicht …"],
        "lock.blink": ["Blink to unlock", "Blinzeln zum Entsperren", "Clignez pour déverrouiller", "Parpadea para desbloquear", "Sbatti le palpebre per sbloccare", "Knipper om te ontgrendelen"],
        "lock.blinkShort": ["Blink", "Blinzeln", "Clignez", "Parpadea", "Sbatti", "Knipper"],
        "lock.scanShort": ["Scan", "Scan", "Scan", "Escaneo", "Scansione", "Scan"],
        "lock.recognized": ["Recognized · unlocking …", "Erkannt · entsperre …", "Reconnu · déverrouillage …", "Reconocido · desbloqueando …", "Riconosciuto · sblocco …", "Herkend · ontgrendelen …"],
        "lock.recognizedShort": ["Recognized", "Erkannt", "Reconnu", "Reconocido", "Riconosciuto", "Herkend"],
        "lock.unlocked": ["Unlocked", "Entsperrt", "Déverrouillé", "Desbloqueado", "Sbloccato", "Ontgrendeld"],

        "missing.face": ["face", "Gesicht", "visage", "cara", "volto", "gezicht"],
        "missing.password": ["password", "Passwort", "mot de passe", "contraseña", "password", "wachtwoord"],
        "missing.camera": ["camera", "Kamera", "caméra", "cámara", "fotocamera", "camera"],
        "missing.accessibility": ["Accessibility", "Bedienungshilfen", "Accessibilité", "Accesibilidad", "Accessibilità", "Toegankelijkheid"],
        "search.scan": ["Scan face", "Gesicht scannen", "Scanner le visage", "Escanear cara", "Scansiona volto", "Gezicht scannen"],
        "search.password": ["Password", "Passwort", "Mot de passe", "Contraseña", "Password", "Wachtwoord"],

        "ax.scanning": ["Face Unlock is looking for your face", "Face Unlock sucht dein Gesicht", "Face Unlock recherche votre visage", "Face Unlock está buscando tu cara", "Face Unlock sta cercando il tuo volto", "Face Unlock zoekt je gezicht"],
        "ax.faceSeen": ["Face seen, blink to unlock", "Gesicht gesehen, blinzeln zum Entsperren", "Visage détecté, clignez pour déverrouiller", "Cara detectada, parpadea para desbloquear", "Volto rilevato, sbatti le palpebre per sbloccare", "Gezicht gezien, knipper om te ontgrendelen"],
        "ax.recognized": ["Face recognized", "Gesicht erkannt", "Visage reconnu", "Cara reconocida", "Volto riconosciuto", "Gezicht herkend"],
        "hud.searching": ["Looking …", "Suche …", "Recherche …", "Buscando …", "Cerco …", "Zoeken …"],
        "card.hello": ["Hello, %@", "Hallo, %@", "Bonjour, %@", "Hola, %@", "Ciao, %@", "Hallo, %@"],
        "card.recognized": ["Face recognized · unlocking …", "Gesicht erkannt · entsperre …", "Visage reconnu · déverrouillage …", "Cara reconocida · desbloqueando …", "Volto riconosciuto · sblocco …", "Gezicht herkend · ontgrendelen …"],

        "hero.cancel": ["Cancel", "Abbrechen", "Annuler", "Cancelar", "Annulla", "Annuleren"],
        "hero.done": ["Done", "Fertig", "Terminé", "Listo", "Fine", "Klaar"],
        "hero.adopt": ["Set limit to %.2f", "Grenze auf %.2f setzen", "Régler la limite à %.2f", "Fijar el límite en %.2f", "Imposta il limite a %.2f", "Grens op %.2f zetten"],
        "hero.scan": ["Scan face", "Gesicht scannen", "Scanner le visage", "Escanear cara", "Scansiona volto", "Gezicht scannen"],
        "hero.rescan": ["Scan again", "Neu scannen", "Scanner à nouveau", "Volver a escanear", "Scansiona di nuovo", "Opnieuw scannen"],
        "hero.test": ["Test", "Testen", "Tester", "Probar", "Prova", "Testen"],
        "step.center0": ["Look straight at the camera", "Schau gerade in die Kamera", "Regardez droit vers la caméra", "Mira de frente a la cámara", "Guarda dritto nella fotocamera", "Kijk recht in de camera"],
        "step.center1": ["One last time, straight ahead", "Zum Schluss noch einmal gerade", "Une dernière fois, de face", "Una última vez, de frente", "Un’ultima volta, dritto", "Nog één keer recht vooruit"],
        "step.left": ["Slowly turn your head left", "Dreh den Kopf langsam nach links", "Tournez lentement la tête à gauche", "Gira la cabeza despacio a la izquierda", "Gira lentamente la testa a sinistra", "Draai je hoofd langzaam naar links"],
        "step.right": ["Now slowly to the right", "Jetzt langsam nach rechts", "Maintenant lentement à droite", "Ahora despacio a la derecha", "Ora lentamente a destra", "Nu langzaam naar rechts"],
        "step.up": ["Lift your chin a little", "Heb das Kinn ein wenig", "Levez un peu le menton", "Levanta un poco la barbilla", "Alza un po’ il mento", "Til je kin een beetje op"],
        "step.down": ["And lower it a little", "Und senk es ein wenig", "Et baissez-le un peu", "Y bájala un poco", "E abbassalo un po’", "En laat hem iets zakken"],
        "hero.saved": ["Face saved", "Gesicht gespeichert", "Visage enregistré", "Cara guardada", "Volto salvato", "Gezicht opgeslagen"],
        "hero.noFace": ["No face in view", "Kein Gesicht im Bild", "Aucun visage visible", "No hay ninguna cara", "Nessun volto inquadrato", "Geen gezicht in beeld"],
        "hero.notYet": ["Not recognized yet", "Noch nicht erkannt", "Pas encore reconnu", "Aún no reconocido", "Non ancora riconosciuto", "Nog niet herkend"],
        "hero.blinkNow": ["Now blink once", "Jetzt einmal blinzeln", "Clignez une fois", "Ahora parpadea una vez", "Ora sbatti le palpebre una volta", "Knipper nu één keer"],
        "hero.checking": ["Checking …", "Prüfe …", "Vérification …", "Comprobando …", "Verifica …", "Controleren …"],
        "hero.ready": ["Face Unlock is set up", "Face Unlock ist eingerichtet", "Face Unlock est configuré", "Face Unlock está configurado", "Face Unlock è configurato", "Face Unlock is ingesteld"],
        "hero.setup": ["Set up your face", "Richte dein Gesicht ein", "Configurez votre visage", "Configura tu cara", "Configura il tuo volto", "Stel je gezicht in"],
        "hero.progress": ["Step %d of %d · %d of %d photos · Good light helps.", "Schritt %d von %d · %d von %d Bildern · Gutes Licht hilft.", "Étape %d sur %d · %d photos sur %d · Une bonne lumière aide.", "Paso %d de %d · %d de %d fotos · La buena luz ayuda.", "Passo %d di %d · %d foto su %d · Una buona luce aiuta.", "Stap %d van %d · %d van %d foto’s · Goed licht helpt."],
        "hero.savedDetail": ["%d photos from 6 angles, only on this Mac. Limit set to %.2f automatically.", "%d Bilder aus 6 Blickwinkeln, nur auf diesem Mac. Grenze automatisch auf %.2f gesetzt.", "%d photos sous 6 angles, uniquement sur ce Mac. Limite réglée automatiquement à %.2f.", "%d fotos desde 6 ángulos, solo en este Mac. Límite fijado automáticamente en %.2f.", "%d foto da 6 angolazioni, solo su questo Mac. Limite impostato automaticamente a %.2f.", "%d foto’s uit 6 hoeken, alleen op deze Mac. Grens automatisch op %.2f gezet."],
        "hero.distance": ["Distance %.2f", "Abstand %.2f", "Distance %.2f", "Distancia %.2f", "Distanza %.2f", "Afstand %.2f"],
        "hero.distanceNone": ["Distance –", "Abstand –", "Distance –", "Distancia –", "Distanza –", "Afstand –"],
        "hero.limit": ["limit %.2f", "Grenze %.2f", "limite %.2f", "límite %.2f", "limite %.2f", "grens %.2f"],
        "hero.matchedDetail": ["%@ · %@ · This is how it unlocks on the lock screen too.", "%@ · %@ · So entsperrt es auch am Sperrbildschirm.", "%@ · %@ · C’est ainsi qu’il déverrouille aussi l’écran verrouillé.", "%@ · %@ · Así también desbloquea en la pantalla de bloqueo.", "%@ · %@ · Così sblocca anche nella schermata di blocco.", "%@ · %@ · Zo ontgrendelt het ook op het vergrendelscherm."],
        "hero.tooFar": ["%@ is above the %@. Stay in the light, look straight at the camera, or use your value.", "%@ liegt über der %@. Bleib im Licht, schau gerade in die Kamera oder übernimm deinen Wert.", "%@ dépasse la %@. Restez à la lumière, regardez la caméra de face ou utilisez votre valeur.", "%@ supera el %@. Mantente en la luz, mira de frente a la cámara o usa tu valor.", "%@ supera il %@. Resta alla luce, guarda dritto nella fotocamera o usa il tuo valore.", "%@ ligt boven de %@. Blijf in het licht, kijk recht in de camera of neem je waarde over."],
        "hero.readyDetail": ["Test the recognition before you rely on it.", "Teste die Erkennung, bevor du dich darauf verlässt.", "Testez la reconnaissance avant de vous y fier.", "Prueba el reconocimiento antes de confiar en él.", "Prova il riconoscimento prima di farci affidamento.", "Test de herkenning voordat je erop vertrouwt."],
        "hero.setupDetail": ["A short guided scan with the camera, like Face ID on iPhone.", "Ein kurzer geführter Scan mit der Kamera, wie bei Face ID am iPhone.", "Un court scan guidé avec la caméra, comme Face ID sur iPhone.", "Un breve escaneo guiado con la cámara, como Face ID en el iPhone.", "Una breve scansione guidata con la fotocamera, come Face ID su iPhone.", "Een korte begeleide scan met de camera, zoals Face ID op de iPhone."],
        "gauge.similar": ["similar", "ähnlich", "similaire", "similar", "simile", "gelijk"],
        "gauge.different": ["different", "fremd", "différent", "distinto", "diverso", "anders"],
        "gauge.best": ["best %.2f", "bester Wert %.2f", "meilleur %.2f", "mejor %.2f", "migliore %.2f", "beste %.2f"],

        "set.enable": ["Unlock with my face", "Mit Gesicht entsperren", "Déverrouiller avec mon visage", "Desbloquear con mi cara", "Sblocca con il mio volto", "Ontgrendelen met mijn gezicht"],
        "set.ready": ["Ready. Lock your Mac with ⌃⌘Q to try it.", "Bereit. Sperre den Mac mit ⌃⌘Q, um es auszuprobieren.", "Prêt. Verrouillez votre Mac avec ⌃⌘Q pour essayer.", "Listo. Bloquea tu Mac con ⌃⌘Q para probarlo.", "Pronto. Blocca il Mac con ⌃⌘Q per provarlo.", "Klaar. Vergrendel je Mac met ⌃⌘Q om het te proberen."],
        "set.missing": ["Still missing: %@", "Es fehlt noch: %@", "Il manque encore : %@", "Aún falta: %@", "Manca ancora: %@", "Nog nodig: %@"],
        "set.how": ["How it works", "So geht’s", "Fonctionnement", "Cómo funciona", "Come funziona", "Zo werkt het"],
        "set.howTip": ["Lock your Mac, then press a key or click. Only then does the camera turn on and look for your face for 30 seconds. Blink once and it unlocks.", "Mac sperren, dann eine Taste drücken oder klicken. Erst dann geht die Kamera an und sucht 30 Sekunden lang dein Gesicht. Einmal blinzeln, dann wird entsperrt.", "Verrouillez votre Mac, puis appuyez sur une touche ou cliquez. La caméra s’allume alors et cherche votre visage pendant 30 secondes. Clignez une fois pour déverrouiller.", "Bloquea tu Mac y pulsa una tecla o haz clic. Solo entonces se enciende la cámara y busca tu cara durante 30 segundos. Parpadea una vez y se desbloquea.", "Blocca il Mac, poi premi un tasto o fai clic. Solo allora la fotocamera si accende e cerca il tuo volto per 30 secondi. Sbatti le palpebre una volta e si sblocca.", "Vergrendel je Mac en druk dan op een toets of klik. Pas dan gaat de camera aan en zoekt 30 seconden naar je gezicht. Knipper één keer en hij ontgrendelt."],
        "set.howValue": ["Lock · key · blink", "Sperren · Taste · Blinzeln", "Verrouiller · touche · clin d’œil", "Bloquear · tecla · parpadeo", "Blocca · tasto · battito", "Vergrendelen · toets · knipperen"],
        "set.last": ["Last lock", "Letzter Sperrvorgang", "Dernier verrouillage", "Último bloqueo", "Ultimo blocco", "Laatste vergrendeling"],
        "set.credentials": ["Login details", "Anmeldedaten", "Identifiants", "Datos de inicio de sesión", "Dati di accesso", "Inloggegevens"],
        "set.credentialsDetail": ["Typed for you after a match. The password stays in this Mac’s keychain.", "Wird nach einem Treffer für dich eingetippt. Das Passwort liegt nur im Schlüsselbund dieses Macs.", "Saisis pour vous après une correspondance. Le mot de passe reste dans le trousseau de ce Mac.", "Se escriben por ti tras una coincidencia. La contraseña se queda en el llavero de este Mac.", "Digitati per te dopo un riconoscimento. La password resta nel portachiavi di questo Mac.", "Worden voor je getypt na een match. Het wachtwoord blijft in de sleutelhanger van deze Mac."],
        "set.recognition": ["Recognition", "Erkennung", "Reconnaissance", "Reconocimiento", "Riconoscimento", "Herkenning"],
        "set.recognitionDetail": ["Further left is stricter. “Test” shows how close your face is.", "Weiter links ist strenger. Mit „Testen“ siehst du den Abstand deines Gesichts.", "Plus à gauche est plus strict. « Tester » montre la distance de votre visage.", "Más a la izquierda es más estricto. «Probar» muestra la distancia de tu cara.", "Più a sinistra è più severo. «Prova» mostra la distanza del tuo volto.", "Verder naar links is strenger. ‘Testen’ toont de afstand van je gezicht."],
        "set.strictness": ["Strictness", "Strenge", "Sévérité", "Rigor", "Severità", "Strengheid"],
        "set.loose": ["Very loose", "Sehr locker eingestellt", "Très permissif", "Muy permisivo", "Molto permissivo", "Erg ruim ingesteld"],
        "set.looseTip": ["The higher the limit, the more likely other faces pass. Scanning again in good light lowers your distance.", "Je höher die Grenze, desto eher passen auch fremde Gesichter. Neu scannen bei gutem Licht senkt deinen Abstand.", "Plus la limite est haute, plus d’autres visages peuvent passer. Un nouveau scan sous une bonne lumière réduit votre distance.", "Cuanto más alto el límite, más fácil que pasen otras caras. Volver a escanear con buena luz reduce tu distancia.", "Più alto è il limite, più è probabile che passino altri volti. Una nuova scansione con buona luce riduce la tua distanza.", "Hoe hoger de grens, hoe eerder andere gezichten passen. Opnieuw scannen bij goed licht verlaagt je afstand."],
        "set.savedFace": ["Saved face", "Gespeichertes Gesicht", "Visage enregistré", "Cara guardada", "Volto salvato", "Opgeslagen gezicht"],
        "set.remove": ["Remove", "Entfernen", "Supprimer", "Eliminar", "Rimuovi", "Verwijderen"],
        "set.none": ["None", "Keins", "Aucun", "Ninguna", "Nessuno", "Geen"],
        "set.permissions": ["Permissions", "Berechtigungen", "Autorisations", "Permisos", "Autorizzazioni", "Toestemmingen"],
        "set.camera": ["Camera", "Kamera", "Caméra", "Cámara", "Fotocamera", "Camera"],
        "set.allowed": ["Allowed", "Erlaubt", "Autorisé", "Permitido", "Consentito", "Toegestaan"],
        "set.allow": ["Allow", "Erlauben", "Autoriser", "Permitir", "Consenti", "Toestaan"],
        "set.accessibility": ["Accessibility", "Bedienungshilfen", "Accessibilité", "Accesibilidad", "Accessibilità", "Toegankelijkheid"],
        "set.accessibilityTip": ["So Droppy can type the password on the lock screen.", "Damit Droppy das Passwort am Sperrbildschirm eintippen kann.", "Pour que Droppy puisse saisir le mot de passe sur l’écran verrouillé.", "Para que Droppy pueda escribir la contraseña en la pantalla de bloqueo.", "Così Droppy può digitare la password nella schermata di blocco.", "Zodat Droppy het wachtwoord op het vergrendelscherm kan typen."],
        "set.open": ["Open", "Öffnen", "Ouvrir", "Abrir", "Apri", "Openen"],
        "set.recheck": ["Check again", "Erneut prüfen", "Vérifier à nouveau", "Comprobar de nuevo", "Controlla di nuovo", "Opnieuw controleren"],
        "set.input": ["Input Monitoring", "Eingabeüberwachung", "Surveillance de l’entrée", "Monitorización de entrada", "Monitoraggio input", "Invoermonitoring"],
        "set.inputTip": ["So a key press on the lock screen starts the scan. Without it, it starts only when the display wakes.", "Damit ein Tastendruck am Sperrbildschirm den Scan startet. Ohne sie startet er nur, wenn das Display aufwacht.", "Pour qu’une touche sur l’écran verrouillé lance le scan. Sans elle, il ne démarre qu’au réveil de l’écran.", "Para que una tecla en la pantalla de bloqueo inicie el escaneo. Sin ella, solo empieza al activarse la pantalla.", "Così un tasto nella schermata di blocco avvia la scansione. Senza, parte solo al risveglio dello schermo.", "Zodat een toets op het vergrendelscherm de scan start. Zonder start hij alleen als het scherm ontwaakt."],

        "cred.username": ["User name", "Benutzername", "Nom d’utilisateur", "Nombre de usuario", "Nome utente", "Gebruikersnaam"],
        "cred.password": ["Password", "Passwort", "Mot de passe", "Contraseña", "Password", "Wachtwoord"],
        "cred.placeholder": ["Mac password", "Mac-Passwort", "Mot de passe du Mac", "Contraseña del Mac", "Password del Mac", "Mac-wachtwoord"],
        "cred.show": ["Show", "Anzeigen", "Afficher", "Mostrar", "Mostra", "Tonen"],
        "cred.hide": ["Hide", "Verbergen", "Masquer", "Ocultar", "Nascondi", "Verbergen"],
        "cred.typeUser": ["Type user name first", "Benutzernamen zuerst eingeben", "Saisir d’abord le nom d’utilisateur", "Escribir primero el nombre de usuario", "Digita prima il nome utente", "Eerst gebruikersnaam typen"],
        "cred.typeUserDetail": ["Only needed if your login window asks for name and password.", "Nur nötig, wenn dein Anmeldefenster Name und Passwort abfragt.", "Nécessaire seulement si la fenêtre de connexion demande nom et mot de passe.", "Solo si tu ventana de inicio pide nombre y contraseña.", "Serve solo se la finestra di accesso chiede nome e password.", "Alleen nodig als je inlogvenster om naam en wachtwoord vraagt."],
        "cred.saved": ["Saved in keychain", "Im Schlüsselbund gespeichert", "Enregistré dans le trousseau", "Guardado en el llavero", "Salvato nel portachiavi", "Bewaard in sleutelhanger"],
        "cred.nothing": ["Nothing saved yet", "Noch nichts gespeichert", "Rien d’enregistré", "Nada guardado aún", "Ancora niente salvato", "Nog niets opgeslagen"],
        "cred.flash": ["Saved", "Gespeichert", "Enregistré", "Guardado", "Salvato", "Opgeslagen"],
        "cred.delete": ["Delete", "Löschen", "Supprimer", "Eliminar", "Elimina", "Verwijderen"],
        "cred.save": ["Save", "Speichern", "Enregistrer", "Guardar", "Salva", "Opslaan"],
    ]
}
