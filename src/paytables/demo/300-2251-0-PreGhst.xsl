<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:x="anything">
	<xsl:namespace-alias stylesheet-prefix="x" result-prefix="xsl" />
	<xsl:output encoding="UTF-8" indent="yes" method="xml" />
	<xsl:include href="../utils.xsl" />

	<xsl:template match="/Paytable">
		<x:stylesheet version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			exclude-result-prefixes="java" xmlns:lxslt="http://xml.apache.org/xslt" xmlns:my-ext="ext1" extension-element-prefixes="my-ext">
			<x:import href="HTML-CCFR.xsl" />
			<x:output indent="no" method="xml" omit-xml-declaration="yes" />

			<!-- TEMPLATE Match: -->
			<x:template match="/">
				<x:apply-templates select="*" />
				<x:apply-templates select="/output/root[position()=last()]" mode="last" />
				<br />
			</x:template>

			<!--The component and its script are in the lxslt namespace and define the implementation of the extension. -->
			<lxslt:component prefix="my-ext" functions="formatJson,retrievePrizeTable,getType">
				<lxslt:script lang="javascript">
					<![CDATA[
					var debugFeed = [];
					var debugFlag = false;
					//var bonusTotal = 0; 
					// Format instant win JSON results.
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function formatJson(jsonContext, translations, prizeTable, prizeValues, prizeNamesDesc)
					{
						var scenario = getScenario(jsonContext);
						var scenarioMainGameYL = getMainGameDataYL(scenario);
						var scenarioMainGame = getMainGameData(scenario);
						var scenarioBonusGameLetterGroups = getBonusGameLetterGroupData(scenario);
						var bonusGameTurns = getBonusGameLosersData(scenario);
						var convertedPrizeValues = (prizeValues.substring(1)).split('|');
						var prizeNames = (prizeNamesDesc.substring(1)).split(',');

						////////////////////
						// Parse scenario //
						////////////////////
						var mgBonusCount = 0;
						var mgPrizeMultiplierCounts = [0,0,0,0,0,0,0,0];
						var mgPrizeRowTotals = [0,0,0,0,0,0,0,0];
						var mgSquareWins = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
						var mgSymb = '';
						var mgPrize = '';
						var mgWildsIndex = -1;
						var doBonusGame = false;
						var bgMultiplier = 1;
						var bgPrizeStr = '';
						var bgTotalPrize = 0;
						var bgRoundEliminated = [0,0,0,0,0,0,0,0,0,0,0,0];

						for (var symbMainIndex=0; symbMainIndex < scenarioMainGame.length; symbMainIndex++)
						{
							var wildRow = false;
							for (var symbIndex=0; symbIndex < scenarioMainGame[symbMainIndex].length; symbIndex++)
							{
								if (isEven(symbIndex))  // Data Contains "Symbol, Prize, Symbol, Prize, Symbol, Prize"
								{
									mgWildsIndex++;
									mgSymb = scenarioMainGame[symbMainIndex][symbIndex];
									mgPrize = scenarioMainGame[symbMainIndex][symbIndex+1];
									// Is mgSymb a wild or winning square?
									if (mgSymb == 'W')
									{
										wildRow = true;
									}
									else if (matchesWinningLetter(mgSymb, scenarioMainGameYL))
									{
										mgSquareWins[mgWildsIndex] = 1;
										mgPrizeMultiplierCounts[symbMainIndex]++;
										mgPrizeRowTotals[symbMainIndex] += getPrizeInCents(convertedPrizeValues[getPrizeNameIndex(prizeNames, mgPrize)]);
									}

									// Is bonus game to be played?
									if (mgSymb == 'Z')
									{
										mgBonusCount++;
										if (mgBonusCount == 3)
										{
										  	doBonusGame = true;
											var bonusPlayChar = "";
											var bonusPlayStr = '';
											for (var bonusIndex=0; bonusIndex < bonusGameTurns.length; bonusIndex += 2)
											{
												bonusPlayChar = bonusGameTurns[bonusIndex]; 
												if (isPrizeSymb(bonusPlayChar))
												{
													bonusPlayStr += bonusPlayChar + ", ";
												}
												else if (bonusPlayChar == "x")
												{
													bgMultiplier++;
													bonusPlayStr += getTranslationByName('multiplierInc', translations) + ", ";
												}
												else if (bonusPlayChar == "e")
												{
													bonusPlayStr += getTranslationByName('emptySegment', translations) + ", ";
												}
												switch(bonusGameTurns[bonusIndex +1])
												{
													case "p":
													bonusPlayStr += getTranslationByName('extraTurn', translations) + ", ";
														break;
													case ".":
														break;
												}
											}
										}
									}
								}
							}
							if (wildRow)
							{
								var wildPrizeIndex = 1;
								for (var wildIndex = (symbMainIndex*3); wildIndex < (symbMainIndex*3) + 3; wildIndex++)
								{
									mgSquareWins[wildIndex] = 2;
									mgPrize = scenarioMainGame[symbMainIndex][wildPrizeIndex];
									mgPrizeRowTotals[symbMainIndex] += getPrizeInCents(convertedPrizeValues[getPrizeNameIndex(prizeNames, mgPrize)]);
									mgPrizeMultiplierCounts[symbMainIndex]++;
									wildPrizeIndex += 2;
								}
							}
							if (mgPrizeMultiplierCounts[symbMainIndex] > 0)
							{
								mgPrizeRowTotals[symbMainIndex] = mgPrizeRowTotals[symbMainIndex] * mgPrizeMultiplierCounts[symbMainIndex];
							}
						}
						if (doBonusGame)
						{
							for (var bgPlayLetterIndex = 0; bgPlayLetterIndex < bonusGameTurns.length; bgPlayLetterIndex++)
							{
								if (isPrizeSymb(bonusGameTurns[bgPlayLetterIndex]))
								{
									for (var bgIndex = 0; bgIndex < scenarioBonusGameLetterGroups.length; bgIndex++)
									{
										for (var bglgIndex = 0; bglgIndex < scenarioBonusGameLetterGroups[bgIndex].length; bglgIndex++)
										{
											if (scenarioBonusGameLetterGroups[bgIndex][bglgIndex].indexOf(bonusGameTurns[bgPlayLetterIndex]) > -1) 
											{
												if ((bgRoundEliminated[bgIndex] > (Math.floor(bgPlayLetterIndex/2) +1)) || (bgRoundEliminated[bgIndex] == 0))
												{
													bgRoundEliminated[bgIndex] = Math.floor(bgPlayLetterIndex/2) +1; // Means that the recorded number will start at 1 to show the round of the loss
												}
											}
										}
									}
								}
							}
							var bgPrize = 0;
							for (bgIndex = 0; bgIndex < bgRoundEliminated.length; bgIndex++)
							{
								if (bgRoundEliminated[bgIndex] == 0)
								{
									bgPrize += getPrizeInCents(convertedPrizeValues[getPrizeNameIndex(prizeNames, 'b' + (bgIndex +1))]);
								}
							}
							bgPrizeStr = getCentsInCurr(bgPrize);
							bgTotalPrize = getCentsInCurr(bgPrize * bgMultiplier);
						}

						///////////////////////
						// Drawing Constants //
						///////////////////////
						const smCellSize   = 34;
						const summaryCellSize = 24;
						const TripleCellSizeX  = 72;
						const TripleCellSizeY  = 48;
						const TripleSummaryCellX = 180;
						const TripleSummaryCellY = 48;
						const cellSizeX    = 72;
						const cellSizeY    = 48;
						const tripleCellTextX = 13;
						const tripleCellTextY = 15;
						const summaryCellTextX = 67;
						const summaryCellTextY = 20;
						const cellMargin   = 1;
						const tinyCellTextX  = 12;
						const tinyCellTextY  = 15;
						const smCellTextX  = 18;
						const smCellTextY  = 19;
						const cellTextX    = 22; 
						const cellTextY    = 5; 
						const cellTextY2   = 20; 
						const colourBlack    = '#000000'; 
						const colourWhite    = '#ffffff';  
						const colourLtBlue   = '#96dcff'; 
						const colourDkBlue   = '#0082bf'; 
						const colourLtPink   = '#ffbbff';
						const colourDkPink   = '#bb00bb'; 
						const colourLtYellow = '#ffff80'; 
						const colourDkYellow = '#969600'; 
						const colourGold     = '#ffff00'; 

						const bonusBorderColours	= [colourLtPink, colourDkPink];
						const bonusCashColours		= [colourLtYellow, colourDkYellow];
						const bonusNumColours		= [colourLtBlue, colourDkBlue];
						const symbolsRequired		= [5,5,5,4,4,4,3,3,3,2,2,2];

						///////////////////////
						// Output Game Parts //
						///////////////////////
						var boxColourStr  = '';
						var textColourStr = '';
						var canvasIdStr   = '';
						var elementStr    = '';
						var symbDesc      = '';
						var symbPrize     = '';
						var symbSpecial   = '';
						var r = [];

						function showSymb(A_strCanvasId, A_strCanvasElement, A_strBoxColour, A_strTextColour, A_strText)
						{
							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + (smCellSize + 2 * cellMargin).toString() + '" height="' + (smCellSize + 2 * cellMargin).toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold 24px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellMargin + 0.5).toString() + ', ' + smCellSize.toString() + ', ' + smCellSize.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strBoxColour + '";');
							r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellMargin + 1.5).toString() + ', ' + (smCellSize - 2).toString() + ', ' + (smCellSize - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strTextColour + '";');
							r.push(canvasCtxStr + '.fillText("' + A_strText + '", ' + smCellTextX.toString() + ', ' + smCellTextY.toString() + ');');
							r.push('</script>');
						}

						function showBonusSymb(A_strCanvasId, A_strCanvasElement)
						{
							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + (summaryCellSize + 2 * cellMargin).toString() + '" height="' + (summaryCellSize + 2 * cellMargin).toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellMargin + 0.5).toString() + ', ' + summaryCellSize.toString() + ', ' + summaryCellSize.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + colourWhite + '";');
							r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellMargin + 1.5).toString() + ', ' + (summaryCellSize - 2).toString() + ', ' + (summaryCellSize - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + colourBlack + '";');
							r.push('</script>');
						}

						function showTripleSymbs(A_strCanvasId, A_strCanvasElement, A_playLetter, A_playPrize, A_squareIndex)
						{
							var L_strCanvasId = A_strCanvasId + A_playLetter + A_playPrize + A_squareIndex;
							var L_strCanvasElement = A_strCanvasElement + A_playLetter + A_playPrize + A_squareIndex;
							var canvasCtxStr = 'canvasContext' + L_strCanvasElement;
							var prizeStr = convertedPrizeValues[getPrizeNameIndex(prizeNames, A_playPrize)];

							var strBoxColour = (mgSquareWins[A_squareIndex] > 0)||(matchesWinningLetter(A_playLetter, scenarioMainGameYL)) ? colourGold : colourWhite;
							var strTextColour = colourBlack;
							symbDesc = ((mgSquareWins[A_squareIndex] > 1) || (A_playLetter == "W")) ? "W" :  getIndexOfPrizeChar(A_playLetter); 

							r.push('<td>');
							r.push('<canvas id="' + L_strCanvasId + '" width="' + (TripleCellSizeX + 2 * cellMargin).toString() + '" height="' + (TripleCellSizeY + 2 * cellMargin).toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + L_strCanvasElement +  ' = document.getElementById("' + L_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + L_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold 24px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellMargin + 0.5).toString() + ', ' + TripleCellSizeX.toString() + ', ' + TripleCellSizeY.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + strBoxColour + '";');
							r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellMargin + 1.5).toString() + ', ' + (TripleCellSizeX - 2).toString() + ', ' + (TripleCellSizeY - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + strTextColour + '";');
							r.push(canvasCtxStr + '.fillText("' + symbDesc + '", ' + (tripleCellTextX + cellTextX).toString() + ', ' + (tripleCellTextY + cellTextY).toString() + ');');		
							r.push(canvasCtxStr + '.font = "bold 10px Arial";');
							r.push(canvasCtxStr + '.fillText("' + prizeStr + '", ' + (tripleCellTextX + cellTextX).toString() + ', ' + (tripleCellTextY + cellTextY2).toString() + ');');
							r.push('</script>');
							r.push('</td>');
						}

						function showTripleSummary(A_strCanvasId, A_strCanvasElement, A_row)
						{
							var L_strCanvasId = A_strCanvasId + 'Multipliers';
							var L_strCanvasElement = A_strCanvasElement + 'Multipliers';
							var canvasCtxStr = 'canvasContext' + L_strCanvasElement;

							var strBoxColour =  (mgPrizeMultiplierCounts[A_row] > 0)||(mgPrizeRowTotals[A_row] > 0) ? colourGold : colourWhite;
							var strTextColour = colourBlack;

							r.push('<td>');
							r.push('<canvas id="' + L_strCanvasId + '" width="' + (TripleSummaryCellX + 2 * cellMargin).toString() + '" height="' + (TripleCellSizeY + 2 * cellMargin).toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + L_strCanvasElement + A_row + ' = document.getElementById("' + L_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + L_strCanvasElement + A_row + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold 18px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellMargin + 0.5).toString() + ', ' + TripleSummaryCellX.toString() + ', ' + TripleCellSizeY.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + strBoxColour + '";');
							r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellMargin + 1.5).toString() + ', ' + (TripleSummaryCellX - 2).toString() + ', ' + (TripleCellSizeY - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + strTextColour + '";');
							if (mgPrizeMultiplierCounts[A_row] > 0)
							{
								r.push(canvasCtxStr + '.fillText("' + mgPrizeMultiplierCounts[A_row] + 'x = ' + getCentsInCurr(mgPrizeRowTotals[A_row]) + '", ' + (summaryCellTextX + cellTextX).toString() + ', ' + (summaryCellTextY + cellTextY).toString() + ');');
							}
							r.push('</script>');
							r.push('</td>');
						}

						function showBonusGrid(A_canvasIdStr, A_elementStr, A_round, A_bonusGame, A_prizeIndex, A_elimNum)
						{
							var canvasCtxStr = 'canvasContext' + A_canvasIdStr;
							const bonusCellHeight = 30;
							const bonusCellWidth  = 18;
							const bonusGridCanvasHeight = 2 * bonusCellHeight; 
							const bonusGridCanvasWidth  = 7 * (bonusCellWidth + 3) + 10 * cellMargin + 10;

							var bonusPrizeText = 'b' + (A_prizeIndex +1); 
							var cashStr        = convertedPrizeValues[getPrizeNameIndex(prizeNames, bonusPrizeText)];
							var winNumStr 	   = '';
							prizeColourStr     = (bgRoundEliminated[bgIndex] > A_round) || (bgRoundEliminated[bgIndex] == 0) ? bonusCashColours[0] : bonusCashColours[1];
							boxColourStr = (bgRoundEliminated[bgIndex] > A_round) || (bgRoundEliminated[bgIndex] == 0) ? bonusBorderColours[0] : bonusBorderColours[1]; 

							r.push('<canvas id="' + A_canvasIdStr + '" width="' + (bonusGridCanvasWidth + 2 * cellMargin).toString() + '" height="' + (bonusGridCanvasHeight + 2 * cellMargin).toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_elementStr + ' = document.getElementById("' + A_canvasIdStr + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_elementStr + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold 14px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellMargin + 0.5).toString() + ', ' + bonusGridCanvasWidth.toString() + ', ' + bonusGridCanvasHeight.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
							r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellMargin + 1.5).toString() + ', ' + (bonusGridCanvasWidth - 2).toString() + ', ' + (bonusGridCanvasHeight - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + colourBlack + '";');
							r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 5.5).toString() + ', ' + (cellMargin + 5.5).toString() + ', ' + (bonusGridCanvasWidth - 10).toString() + ', ' + (bonusGridCanvasHeight - 10).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + prizeColourStr + '";');
							r.push(canvasCtxStr + '.fillText("' + cashStr + '", ' + (bonusGridCanvasWidth / 2 + 1).toString() + ', ' + (bonusGridCanvasHeight / 2 + 15).toString() + ');');

							var baseLeft =  Math.floor((bonusGridCanvasWidth - symbolsRequired[A_prizeIndex] * (bonusCellWidth + 3)) / 2) + 2;
							for (var countWinSymbs = 0; countWinSymbs < symbolsRequired[A_prizeIndex]; countWinSymbs++)
							{
								winNumStr = getIndexOfBonusChar(A_bonusGame[countWinSymbs]); 
								textColourStr = (winNumStr == A_elimNum) ? colourGold : (bgRoundEliminated[bgIndex] > A_round) || (bgRoundEliminated[bgIndex] == 0) ? bonusNumColours[0] : bonusNumColours[1];
								r.push(canvasCtxStr + '.font = "bold 18px Arial";');
								r.push(canvasCtxStr + '.fillStyle = "' + textColourStr + '";');
								r.push(canvasCtxStr + '.fillText("' + winNumStr + '", ' + (baseLeft + 5 + countWinSymbs * (bonusCellWidth + 6)).toString() + ', ' + (bonusCellHeight / 2 + 10).toString() + ');');
							}

							r.push('</script>');
						}

						/////////////////////
						// Play Game Parts //
						/////////////////////
						r.push('<div style="float:left; margin-right:50px">');
						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td align="center" colspan="3">' + getTranslationByName("titleLuckyNumbers", translations) + '</td>');
						r.push('</tr>');

						for (var gameIndex = 0; gameIndex < scenarioMainGameYL.length; gameIndex ++)
						{
							temp = scenarioMainGameYL[gameIndex];
							textStr = getIndexOfPrizeChar(temp); 
							canvasIdStr  = 'cvsMainGameYLSummaryPrize' + temp;
							elementStr   = 'eleMainGameYLSummarySymb' + temp;
							boxColourStr  = colourWhite;
							textColourStr = colourBlack;

							r.push('<td>');
							showSymb(canvasIdStr, elementStr, boxColourStr, textColourStr, textStr);
							r.push('</td>');
						}

						r.push('</tr>');
						r.push('</table>');
						r.push('</div>');

						r.push('<div style="float:left">');
						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td align="center" colspan="3">' + getTranslationByName("titleBonusCollected", translations) + '</td>');
						r.push('</tr>');
						r.push('<tr>');

 						for (var gameIndex = 1; gameIndex < 4; gameIndex++)
						{
							boolDiamond = (gameIndex <= mgBonusCount);
							canvasIdStr  = 'cvsMainGameBonusSummaryPrize' + gameIndex;
							elementStr   = 'eleMainGameBonusSummarySymb' + gameIndex;

							r.push('<td>');
							if (boolDiamond)
							{
								r.push('&#128142;');
							}
							else
							{
								showBonusSymb(canvasIdStr, elementStr);
							}
							r.push('</td>');
						}

						r.push('</tr>');
						r.push('</table>');
						r.push('</div>');

						r.push('<p style="clear:both"><br></p>');

						///////////////
						// Main Game //
						///////////////
						r.push('<div style="float:left; margin-right:50px">');
						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td align="center" colspan="3">' + getTranslationByName("titleWinningNumbers", translations) + '</td>');
						r.push('</tr>');

						var playLetter = '';
						var playPrize =  '';
						var squareIndex = 0;
						for (var gameIndex = 0; gameIndex < scenarioMainGame.length; gameIndex ++)
						{
							temp = scenarioMainGame[gameIndex].replace(/\./g, '1');  // replacing full stops as they seem to be causing issues
							r.push('<tr>');
							for (var letterIndex = 0; letterIndex < 3; letterIndex++)
							{
								var localIndex = letterIndex * 2;
								playLetter = temp[localIndex];
								playPrize  = temp[localIndex +1];
								canvasIdStr  = 'cvsMainGameSummaryPrize' + temp;
								elementStr   = 'eleMainGameSummarySymb' + temp;
								if (playLetter == "Z")
								{
									r.push('<td style="text-align:center;font:36px Arial">');
									r.push('&#128142;');
									r.push('</td>');
								}
								else
								{
									showTripleSymbs(canvasIdStr, elementStr, playLetter, playPrize, squareIndex);
								}
								squareIndex++;
							}
							r.push('</tr>');
						}
						r.push('</table>');
						r.push('</div>');

						////////////////////
						// Row Total Wins //
						////////////////////
						r.push('<div style="float:left">');
						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td align="center" colspan="1">' + getTranslationByName("titleRowTotalWin", translations) + '</td>');
						r.push('</tr>');
						for (var gameIndex = 0; gameIndex < scenarioMainGame.length; gameIndex ++)
						{
							temp = scenarioMainGame[gameIndex].replace(/\./g, '1');  // replacing full stops as they seem to be causing issues
							canvasIdStr  = 'cvsMainGameSummaryPrize' + temp + gameIndex;
							elementStr   = 'eleMainGameSummarySymb' + temp + gameIndex;

							r.push('<tr>');
							showTripleSummary(canvasIdStr, elementStr, gameIndex);
							r.push('</tr>');
						}
						r.push('</table>');
						r.push('</div>');

						r.push('<p style="clear:both"><br></p>');

						////////////////
						// Bonus Game //
						////////////////
						if (doBonusGame)
						{
							var turnSummary = '';
							r.push('<div style="float:left">');
							r.push('<p>' + getTranslationByName("bonusGame", translations) + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');							
							
							for (var bgSpinIndex = 0; bgSpinIndex < Math.floor(bonusGameTurns.length/2); bgSpinIndex++)
							{
								var spinStr = getTranslationByName("afterSpin", translations) + ' ' + parseInt(bgSpinIndex + 1);
								var bonusPlayChar = bonusGameTurns[bgSpinIndex *2];
								var bonusPlayChar2 = bonusGameTurns[(bgSpinIndex *2) +1];
								var spinStr2 = '';
								if (bonusPlayChar2 == 'p')
								{
									spinStr2 = getTranslationByName("bonusTurn", translations);
								}
								if (isPrizeSymb(bonusPlayChar))
								{
									var elimNum = getIndexOfBonusChar(bonusPlayChar); 
									r.push('<tr class="tablebody">');
									r.push('<td valign="top">' + spinStr + '<br>' + getTranslationByName("eliminates", translations) + ' ' + elimNum + '<br>' + spinStr2 + '</td>');
									r.push('<td style="padding-bottom:25px">');
									r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

									for (var bgRowIndex = 0; bgRowIndex < 4; bgRowIndex++)
									{
										turnSummary = getTranslationByName("turnSummary", translations) + ": ";
										r.push('<tr class="tablebody">');

										for (var bgColIndex = 0; bgColIndex < 3; bgColIndex++)
										{
											bgIndex      = bgRowIndex * 3 + bgColIndex;
											canvasIdStr  = 'cvsBonusGame' + bgSpinIndex.toString() + '_' + bgIndex.toString();
											elementStr   = 'eleBonusGame' + bgSpinIndex.toString() + '_' + bgIndex.toString();

											r.push('<td align="center">');
											showBonusGrid(canvasIdStr, elementStr, bgSpinIndex +1, scenarioBonusGameLetterGroups[bgIndex], bgIndex, elimNum);		
											r.push('</td>');
										}
										r.push('</tr>');
									}

									r.push('</table>');

									r.push('</td>');
									r.push('</tr>');
								}
								else
								{
									if (bonusPlayChar == "e" ) 
									{
										spinStr += '<br>' + getTranslationByName("emptyCell", translations) + '<br>' + spinStr2;
									}
									else if  (bonusPlayChar == "x")
									{
										spinStr += '<br>' + getTranslationByName("multiplierPlus", translations) + '<br>' + spinStr2;
									}

									r.push('<tr class="tablebody">');
									r.push('<td valign="top">' + spinStr + '</td>');
									r.push('</td>');
									r.push('</tr>');
								}
							}
							r.push('<tr class="tablebody">');
							r.push('<td valign="top">' + getTranslationByName("bonusMultiplier", translations) + ' = ' + bgMultiplier + '</td>');
							r.push('</tr>');
							r.push('<tr class="tablebody">');
							r.push('<td valign="top">' + getTranslationByName("bonusTotal", translations) + '<br>' + bgPrizeStr + ' x ' + bgMultiplier + ' = ' + bgTotalPrize + '</td>'); 
							r.push('</tr>');

							r.push('</table>');
							r.push('</div>');
						}

						r.push('<p>&nbsp;</p>');

						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						// !DEBUG OUTPUT TABLE
						if(debugFlag)
						{
							// DEBUG TABLE
							//////////////////////////////////////
							r.push('<table border="0" cellpadding="2" cellspacing="1" width="100%" class="gameDetailsTable" style="table-layout:fixed">');
							for(var idx = 0; idx < debugFeed.length; ++idx)
 							{
								if(debugFeed[idx] == "")
									continue;
								r.push('<tr>');
 								r.push('<td class="tablebody">');
								r.push(debugFeed[idx]);
 								r.push('</td>');
	 							r.push('</tr>');
							}
							r.push('</table>');
						}
						return r.join('');
					}

					// Input: A list of Price Points and the available Prize Structures for the game as well as the wagered price point
					// Output: A string of the specific prize structure for the wagered price point
					function retrievePrizeTable(pricePoints, prizeStructures, wageredPricePoint)
					{
						var pricePointList = pricePoints.split(",");
						var prizeStructStrings = prizeStructures.split("|");

						for(var i = 0; i < pricePoints.length; ++i)
						{
							if(wageredPricePoint == pricePointList[i])
							{
								return prizeStructStrings[i];
							}
						}

						return "";
					}

					// Input: Json document string containing 'scenario' at root level.
					// Output: Scenario value.
					function getScenario(jsonContext)
					{
						// Parse json and retrieve scenario string.
						var jsObj = JSON.parse(jsonContext);
						var scenario = jsObj.scenario;

						// Trim null from scenario string.
						scenario = scenario.replace(/\0/g, '');

						return scenario;
					}

					// Input: Json document string containing 'amount' at root level.
					// Output: Price Point value.
					function getPricePoint(jsonContext)
					{
						// Parse json and retrieve price point amount
						var jsObj = JSON.parse(jsonContext);
						var pricePoint = jsObj.amount;

						return pricePoint;
					}

					function getMainGameDataYL(scenario)
					{
						return scenario.split(":")[0];
					}

					function getMainGameData(scenario)
					{
						var firstHalfData = scenario.split("|")[0];
						var resultDataWhole = firstHalfData.split(":")[1];
						return resultDataWhole.split(",");
					}

					function getBonusGameLetterGroupData(scenario)
					{
						var secondHalfData = scenario.split("|")[1];
						var resultDataWhole = secondHalfData.split(":")[0];
						return resultDataWhole.split(",");
					}

					function getBonusGameLosersData(scenario)
					{
						var secondHalfData = scenario.split("|")[1];
						return secondHalfData.split(":")[1];
					}

					function matchesWinningLetter(letter, winningLetters)
					{
						var numRes = winningLetters.indexOf(letter);
						if (numRes == -1)
						{
							return (false)
						}
						else
						{
							return (true);
						}
					}

					function isEven(n) 
					{
					   return n % 2 == 0;
					}

					var bCurrSymbAtFront = false;
					var strCurrSymb      = '';
					var strDecSymb  	 = '';
					var strThouSymb      = '';

					function getPrizeInCents(AA_strPrize)
					{
						var strPrizeWithoutCurrency = AA_strPrize.replace(new RegExp('[^0-9., ]', 'g'), '');
						var iPos 					= AA_strPrize.indexOf(strPrizeWithoutCurrency);
						var iCurrSymbLength 		= AA_strPrize.length - strPrizeWithoutCurrency.length;
						var strPrizeWithoutDigits   = strPrizeWithoutCurrency.replace(new RegExp('[0-9]', 'g'), '');

						strDecSymb 		 = strPrizeWithoutCurrency.substr(-3,1);									
						bCurrSymbAtFront = (iPos != 0);									
						strCurrSymb 	 = (bCurrSymbAtFront) ? AA_strPrize.substr(0,iCurrSymbLength) : AA_strPrize.substr(-iCurrSymbLength);
						strThouSymb      = (strPrizeWithoutDigits.length > 1) ? strPrizeWithoutDigits[0] : strThouSymb;

						return parseInt(AA_strPrize.replace(new RegExp('[^0-9]', 'g'), ''), 10);
					}

					function getCentsInCurr(AA_iPrize)
					{
						var strValue = AA_iPrize.toString();

						strValue = (strValue.length < 3) ? ('00' + strValue).substr(-3) : strValue;
						strValue = strValue.substr(0,strValue.length-2) + strDecSymb + strValue.substr(-2);
						strValue = (strThouSymb != '' && strValue.length > 6) ? strValue.substr(0,strValue.length-6) + strThouSymb + strValue.substr(-6) : strValue;
						strValue = (bCurrSymbAtFront) ? strCurrSymb + strValue : strValue + strCurrSymb;

						return strValue;
					}

					function getIndexOfBonusChar(bonusChar)
					{
						return bonusChar.charCodeAt(0) - 'A'.charCodeAt(0) +1;
					}

					function getIndexOfPrizeChar(prizeChar)
					{
						return prizeChar.charCodeAt(0) - 'a'.charCodeAt(0) +1;
					}

					function isPrizeSymb(dataChar)
					{
						return (dataChar >= 'A' && dataChar <= 'N');
					}

					// Input: "A,B,C,D,..." and "A"
					// Output: index number
					function getPrizeNameIndex(prizeNames, currPrize)
					{
						for(var i = 0; i < prizeNames.length; ++i)
						{
							if(prizeNames[i] == currPrize)
							{
								return i;
							}
						}
					}

					////////////////////////////////////////////////////////////////////////////////////////
					function registerDebugText(debugText)
					{
						debugFeed.push(debugText);
					}

					/////////////////////////////////////////////////////////////////////////////////////////
					function getTranslationByName(keyName, translationNodeSet)
					{
						var index = 1;
						while(index < translationNodeSet.item(0).getChildNodes().getLength())
						{
							var childNode = translationNodeSet.item(0).getChildNodes().item(index);
							
							if(childNode.name == "phrase" && childNode.getAttribute("key") == keyName)
							{
								registerDebugText("Child Node: " + childNode.name);
								return childNode.getAttribute("value");
							}
							
							index += 1;
						}
					}

					// Grab Wager Type
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function getType(jsonContext, translations)
					{
						// Parse json and retrieve wagerType string.
						var jsObj = JSON.parse(jsonContext);
						var wagerType = jsObj.wagerType;

						return getTranslationByName(wagerType, translations);
					}
					]]>
				</lxslt:script>
			</lxslt:component>

			<x:template match="root" mode="last">
				<table border="0" cellpadding="1" cellspacing="1" width="100%" class="gameDetailsTable">
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWager']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/WagerOutcome[@name='Game.Total']/@amount" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWins']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/PrizeOutcome[@name='Game.Total']/@totalPay" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
				</table>
			</x:template>

			<!-- TEMPLATE Match: digested/game -->
			<x:template match="//Outcome">
				<x:if test="OutcomeDetail/Stage = 'Scenario'">
					<x:call-template name="Scenario.Detail" />
				</x:if>
			</x:template>

			<!-- TEMPLATE Name: Scenario.Detail (base game) -->
			<x:template name="Scenario.Detail">
				<x:variable name="odeResponseJson" select="string(//ResultData/JSONOutcome[@name='ODEResponse']/text())" />
				<x:variable name="translations" select="lxslt:nodeset(//translation)" />
				<x:variable name="wageredPricePoint" select="string(//ResultData/WagerOutcome[@name='Game.Total']/@amount)" />
				<x:variable name="prizeTable" select="lxslt:nodeset(//lottery)" />

				<table border="0" cellpadding="0" cellspacing="0" width="100%" class="gameDetailsTable">
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='wagerType']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="my-ext:getType($odeResponseJson, $translations)" disable-output-escaping="yes" />
						</td>
					</tr>
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='transactionId']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="OutcomeDetail/RngTxnId" />
						</td>
					</tr>
				</table>
				<br />			
				
				<x:variable name="convertedPrizeValues">
					<x:apply-templates select="//lottery/prizetable/prize" mode="PrizeValue"/>
				</x:variable>

				<x:variable name="prizeNames">
					<x:apply-templates select="//lottery/prizetable/description" mode="PrizeDescriptions"/>
				</x:variable>


				<x:value-of select="my-ext:formatJson($odeResponseJson, $translations, $prizeTable, string($convertedPrizeValues), string($prizeNames))" disable-output-escaping="yes" />
			</x:template>

			<x:template match="prize" mode="PrizeValue">
					<x:text>|</x:text>
					<x:call-template name="Utils.ApplyConversionByLocale">
						<x:with-param name="multi" select="/output/denom/percredit" />
					<x:with-param name="value" select="text()" />
						<x:with-param name="code" select="/output/denom/currencycode" />
						<x:with-param name="locale" select="//translation/@language" />
					</x:call-template>
			</x:template>
			<x:template match="description" mode="PrizeDescriptions">
				<x:text>,</x:text>
				<x:value-of select="text()" />
			</x:template>

			<x:template match="text()" />
		</x:stylesheet>
	</xsl:template>

	<xsl:template name="TemplatesForResultXSL">
		<x:template match="@aClickCount">
			<clickcount>
				<x:value-of select="." />
			</clickcount>
		</x:template>
		<x:template match="*|@*|text()">
			<x:apply-templates />
		</x:template>
	</xsl:template>
</xsl:stylesheet>
