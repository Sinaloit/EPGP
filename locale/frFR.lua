local L = Apollo.GetPackage("Gemini:Locale-1.0").tPackage:NewLocale("EPGP", "frFR")
if not L then return end

--[[ Proper Translations ]]--

L["Alts"] = "Rerolls"
L["A member is awarded EP"] = "Un membre a gagné des EP"
L["A member is credited GP"] = "Un crédit de GP à été attribué à un membre"
L["A new tier is here!  You should probably reset or rescale GP (Interface -> Options -> AddOns -> EPGP)!"] = "Un nouveau Tier est là! Vous devriez réinitialiser ou recalibrer les GP (Interface -> Options -> AddOns -> EPGP)!" -- Needs review
L["An item was disenchanted or deposited into the guild bank"] = "Un objet à été désenchanté ou déposé dans la banque de la guilde."
L["Announce"] = "Annoncer"
L["Announce medium"] = "Canal pour les annonces"
L["Announcement of EPGP actions"] = "Annonce des actions EPGP"
L["Announces EPGP actions to the specified medium."] = "Annoncer les actions EPGP sur le canal spécifié."
L["Announce when:"] = "Annoncer quand :"
L["Automatic boss tracking"] = "Suivi automatique du boss"
L["Automatic boss tracking by means of a popup to mass award EP to the raid and standby when a boss is killed."] = "Vérification automatique par l'intermédiaire d'un popup pour créditer des EP en lot au raid et aux membres réservés (standby) quand un boss a été tué."
L["Automatic handling of the standby list through whispers when in raid. When this is enabled, the standby list is cleared after each reward."] = "Gestion automatique de la liste de réserve par intermédiaire d'un message privé (whisper) lorsque vous est dans un raid. lorsque ceci est sélectionné, la liste de réserve (standby) sera vidée après chaque attribution de points."
L["Automatic loot tracking"] = "Suivi automatique du butin"
L["Automatic loot tracking by means of a popup to assign GP to the toon that received loot. This option only has effect if you are in a raid and you are either the Raid Leader or the Master Looter."] = "Attribution de GP automatique par intermédiaire d'un popup lorsqu'un loot a été reçus. Cette option ce prend en charge seulement si vous est dans un raid et que vous êtes soit le Raid Leader ou le Loot Master."
L["Award EP"] = "Gain d'EP"
L["Awards for wipes on bosses. Requires DBM, DXE, or BigWigs"] = "Récompenses pour échecs sur les Boss. Requiert DBM, DWE, ou BigWigs."
L["Base GP should be a positive number"] = "Le GP de base doit être un nombre positif"
L["Boss"] = "Boss"
L["Credit GP"] = "Créditer des GP"
L["Credit GP to %s"] = "Créditer des GP à %s"
L["Custom announce channel name"] = "Canal de l'annonce personnalisé" -- Needs review
L["Decay"] = "Réduction"
L["Decay EP and GP by %d%%?"] = "Réduire les EP et les GP de %d%% ?" -- Needs review
L["Decay of EP/GP by %d%%"] = "Réduction d'EP/GP de %d%%"
L["Decay Percent should be a number between 0 and 100"] = "Le pourcentage de réduction devrait être un nombre entre 0 et 100"
L["Decay=%s%% BaseGP=%s MinEP=%s Extras=%s%%"] = "Décroissance=%s%% BaseGP=%s MinEP=%s Suppl=%s%%"
L["default"] = "défaut" -- Needs review
L["%+d EP (%s) to %s"] = "%+d EP (%s) à %s"
L["%+d GP (%s) to %s"] = "%+d GP (%s) à %s"
L["%d or %d"] = "%d ou %d"
L["Do you want to resume recurring award (%s) %d EP/%s?"] = "Voulez-vous à nouveau donner (%s) %d EP/%s périodiquement ?"
L["EP/GP are reset"] = "Les EP/GP ont été réinitialisés"
L["EPGP decay"] = "Décôte EPGP"
L["EPGP is an in game, relational loot distribution system"] = "EPGP est, dans le jeu, un système relationnel de distribution de butin"
L["EPGP is using Officer Notes for data storage. Do you really want to edit the Officer Note by hand?"] = "EPGP utilise les notes d'officiers pour stocker ses données. Souhaitez-vous réellement éditer manuellement la note d'officier ?"
L["EPGP reset"] = "Réinitialiser EPGP"
L["EP Reason"] = "Raison de l'EP"
L["expected number"] = "nombre attendu" -- Needs review
L["Export"] = "Exporter"
L["Extras Percent should be a number between 0 and 100"] = "Pourcentage supplémentaire devrait être un nombre compris entre 0 et 100"
L["GP: %d"] = "GP: %d"
L["GP: %d or %d"] = "GP: %d ou %d"
L["GP is rescaled for the new tier"] = "les GP ont été recalibré pour le nouveau Tier" -- Needs review
L["GP (not EP) is reset"] = "GP (pas les EP) réinitialisé" -- Needs review
L["GP (not ep) reset"] = "réinitialiser GP (pas les EP)" -- Needs review
L["GP on tooltips"] = "GP sur les infos (tooltip)"
L["GP Reason"] = "Raison du GP"
L["GP rescale for new tier"] = "réinitialiser les GP pour le nouveau Tier" -- Needs review
L["Guild or Raid are awarded EP"] = "Les EP ont été attribués à la Guilde/Raid"
L["Hint: You can open these options by typing /epgp config"] = "Astuce : vous pouvez ouvrir ces options en entrant /epgp config"
L["Idle"] = "Inactif"
L["If you want to be on the award list but you are not in the raid, you need to whisper me: 'epgp standby' or 'epgp standby <name>' where <name> is the toon that should receive awards"] = "Si vous souhaitez être sur la liste des gains mais que vous n'êtes pas dans le raid, vous devez me chuchoter : 'epgp standby' ou 'epgp standby <nom>' où <nom> est le membre qui devrait recevoir les gains"
L["Ignoring EP change for unknown member %s"] = "Ignore les changements d'EP pour le membre inconnu %s"
L["Ignoring GP change for unknown member %s"] = "Ignore les changements de GP pour le membre inconnu %s"
L["Import"] = "Importer"
L["Importing data snapshot taken at: %s"] = "Importation"
L["invalid input"] = "entrée invalide" -- Needs review
L["Invalid officer note [%s] for %s (ignored)"] = "Note d'officier invalide [%s] pour %s (ignoré)"
L["List errors"] = "Lister les erreurs"
L["Lists errors during officer note parsing to the default chat frame. Examples are members with an invalid officer note."] = "Liste les erreurs lors du rapport des notes d'officiers sur la fenêtre de discussion par défaut, comme lorsque des membres ont une note d'officier invalide, par exemple."
L["Loot"] = "Butin"
L["Loot tracking threshold"] = "Seuil du suivi de butin"
L["Make sure you are the only person changing EP and GP. If you have multiple people changing EP and GP at the same time, for example one awarding EP and another crediting GP, you *are* going to have data loss."] = "Vérifiez que vous êtes la seule personne changeant les EP et GP. Si vous avez plusieurs personnes changeant les EP et les GP en même temps, par example une récompensant les EP et l'autre créditant les GP, vous risquez une perte de données"
L["Mass EP Award"] = "Gain d'EP en masse"
L["Min EP should be a positive number"] = "L'EP minimum doit être un nombre positif"
L["must be equal to or higher than %s"] = "doit être supérieur ou égale à %s" -- Needs review
L["must be equal to or lower than %s"] = "doit être inférieur ou égale à %s" -- Needs review
L["Next award in "] = "Prochain gain dans"
-- L["off"] = ""
-- L["on"] = ""
L["Only display GP values for items at or above this quality."] = "Afficher les GP uniquement pour les objets de cette qualité ou meilleur." -- Needs review
L["Open the configuration options"] = "Accéder aux options de configuration"
L["Open the debug window"] = "Ouvrir la fenêtre de débogage"
L["Other"] = "Autre"
L["Outsiders should be 0 or 1"] = "Les joueurs en attente doivent être à 0 ou 1" -- Needs review
L["Paste import data here"] = "Copier les données importées ici"
L["Personal Action Log"] = "Historique des actions personnelles"
L["Provide a proposed GP value of armor on tooltips. Quest items or tokens that can be traded for armor will also have a proposed GP value."] = "Fourni une valeur GP indicative sur les infos (tooltip) des armures. Les objets de quête ou les marques (token) qui peuvent être échangés contre des armures ont également une valeur GP indiquée"
L["Quality threshold"] = "Seuil de qualité"
L["Recurring"] = "Récurrent"
L["Recurring awards resume"] = "Reprise des récompenses périodiques"
L["Recurring awards start"] = "Les récompenses périodiques démarrent"
L["Recurring awards stop"] = "Les récompenses périodiques sont stoppées"
L["Redo"] = "Refaire"
L["Re-scale all main toons' GP to current tier?"] = "Recalibrer les GP de tous les main pour le nouveau Tier" -- Needs review
L["Rescale GP"] = "Recalibrer les GP" -- Needs review
-- L["Rescale GP of all members of the guild. This will reduce all main toons' GP by a tier worth of value. Use with care!"] = ""
L["Reset all main toons' EP and GP to 0?"] = "Réinitialiser tous les principaux membres d'EP et GP à 0 ?"
L["Reset all main toons' GP to 0?"] = "Réinitialiser à 0 les GP de tous les main" -- Needs review
L["Reset EPGP"] = "Réinitialiser EPGP"
L["Reset only GP"] = "Réinitialiser uniquement les GP" -- Needs review
L["Resets EP and GP of all members of the guild. This will set all main toons' EP and GP to 0. Use with care!"] = "Réinitialise les EP et GP de tous les membres de la guilde. Cela réinitialisera tous les principaux membres d'EP et GP à 0. À utiliser avec précaution !"
L["Resets GP (not EP!) of all members of the guild. This will set all main toons' GP to 0. Use with care!"] = "Réinitialise les GP (pas les EP!) de tous les membres de la guilde. Cela va remettre tous les main à 0 GP. A utiliser avec précaution." -- Needs review
L["Resume recurring award (%s) %d EP/%s"] = "Repris l'attribution d'EP automatique (%s) %d EP/%s"
L["%s: %+d EP (%s) to %s"] = "%s: %+d EP (%s) à %s"
L["%s: %+d GP (%s) to %s"] = "%s : %+d GP (%s) à %s"
L["Sets loot tracking threshold, to disable the popup on loot below this threshold quality."] = "Fixe le seuil de suivi de butin, pour désactiver les popup sur le butin de qualité inférieure au seuil."
L["Sets the announce medium EPGP will use to announce EPGP actions."] = "Régler la moyenne d'annonces d'EPGP qui sera utilisée afin d'annoncer les actions d'EPGP."
L["Sets the custom announce channel name used to announce EPGP actions."] = "Régler le nom du canal personnalisé de l'annonce utilisé pour annoncer les actions d'EPGP."
L["'%s' - expected 'on', 'off' or 'default', or no argument to toggle."] = "'%s' -  'on' ou 'off' ou 'default' ou vide pour activer." -- Needs review
L["'%s' - expected 'on' or 'off', or no argument to toggle."] = "'%s' -  'on' ou 'off' ou vide pour activer." -- Needs review
L["'%s' - expected 'RRGGBBAA' or 'r g b a'."] = "'%s' - 'RRGGBBAA' ou 'r g b a' attendu." -- Needs review
L["'%s' - expected 'RRGGBB' or 'r g b'."] = "'%s' - 'RRGGBB' ou 'r g b' attendu." -- Needs review
L["Show everyone"] = "Afficher tout le monde"
L["'%s' - Invalid Keybinding."] = "'%s' - Raccourcis invalide." -- Needs review
L["%s is added to the award list"] = "%s est ajouté à la liste des gains"
L["%s is already in the award list"] = "%s est déjà dans la liste des gains"
L["%s is dead. Award EP?"] = "%s est mort. Gain d'EP ?"
L["%s is not eligible for EP awards"] = "%s n'est pas éligible pour les gains d'EP"
L["%s is now removed from the award list"] = "%s est à présent supprimé de la liste des gains"
L["Some english word"] = "Quelques mots d'anglais" -- Needs review
L["Some english word that doesn't exist"] = "Quelques mots d'anglais qui n'existe pas" -- Needs review
L["'%s' '%s' - expected 'on', 'off' or 'default', or no argument to toggle."] = "'%s' '%s' -  'on' ou 'off' ou 'default' ou vide pour activer." -- Needs review
L["'%s' '%s' - expected 'on' or 'off', or no argument to toggle."] = "'%s' '%s' - 'on' ou 'off' ou vide pour activer." -- Needs review
L["%s: %s to %s"] = [=[a
]=]
L["Standby"] = "En attente"
L["Standby whispers in raid"] = "Membres de réserve chuchotez lors d'un raid"
L["Start recurring award (%s) %d EP/%s"] = "Commencer la collecte des gains (%s) %d EP/%s"
L["Stop recurring award"] = "Arrêter la collecte des gains"
L["%s to %s"] = [=[a
]=]
-- L["string1"] = ""
L["'%s' - values must all be either in the range 0-1 or 0-255."] = "'%s' - valeurs comprises entre 0-1 ou 0-255." -- Needs review
L["'%s' - values must all be either in the range 0..1 or 0..255."] = "'%s' - valeurs comprises entre 0..1 ou 0..255." -- Needs review
L["The imported data is invalid"] = "Les données importées ne sont pas valides"
L["To export the current standings, copy the text below and post it to: %s"] = "Pour exporter le classement actuel, copier le texte suivant et copier le sur: %s"
L["Tooltip"] = "Infos (tooltip)"
L["To restore to an earlier version of the standings, copy and paste the text from: %s"] = "Pour restaurer une version précédente du classement, copier et coller le texte depuis: %s"
L["Undo"] = "Annuler"
L["unknown argument"] = "argument inconnu" -- Needs review
L["unknown selection"] = "sélection inconnue" -- Needs review
L["Using %s for boss kill tracking"] = "Utilise %s pour la surveillance de la mort d'un boss"
L["Value"] = "Valeur"
L["Whisper"] = "Chuchoter"
L["Wipe awards"] = "Récompenses de wipe"
L["Wiped on %s. Award EP?"] = "Wipe sur %s. Attribuer EP?"
L["You can now check your epgp standings and loot on the web: http://www.epgpweb.com"] = "Vous pouvez maintenant vérifier votre rang EPGP et loot sur le web: http://epgpweb.com"

--[[ Google Translations ]]--
