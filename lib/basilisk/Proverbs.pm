package basilisk::Proverbs;
use strict;
use warnings;

my @proverbs = (
q|<a href="http://senseis.xmp.net/?page=YourOpponentsGoodMoveIsYourGoodMove">Your opponent&#039;s good move is your good move</a>|,
q|<a href="http://senseis.xmp.net/?page=TheOpponentsVitalPointIsMyVitalPoint">The opponent&#039;s vital point is my vital point</a>|,
q|<a href="http://senseis.xmp.net/?page=PlayOnThePointOfSymmetry">Play on the point of symmetry</a>|,
q|<a href="http://senseis.xmp.net/?page=PlayDoubleSenteEarly">Play double sente early</a>|,
q|<a href="http://senseis.xmp.net/?page=SenteGainsNothing">Sente gains nothing</a>|,
q|<a href="http://senseis.xmp.net/?page=BewareOfGoingBackToPatchUp">Beware of going back to patch up</a>|,
q|<a href="http://senseis.xmp.net/?page=DontFollowProverbsBlindly">Don&#039;t follow proverbs blindly</a>|,
q|<a href="http://senseis.xmp.net/?page=WhenInDoubtTenuki">When in doubt, Tenuki</a>|,
q|<a href="http://senseis.xmp.net/?page=DontGoFishingWhileYourHouseIsOnFire">Don&#039;t go fishing while your house is on fire</a>|,
q|<a href="http://senseis.xmp.net/?page=ThereIsDeathInTheHane">There is death in the hane</a>|,
q|<a href="http://senseis.xmp.net/?page=HaneCutPlacement">Hane, Cut, Placement</a>|,
q|<a href="http://senseis.xmp.net/?page=LearnTheEyestealingTesuji">Learn the eyestealing tesuji</a>|,
q|<a href="http://senseis.xmp.net/?page=SixDieButEightLive">Six die but eight live</a> (on the <a href="http://senseis.xmp.net/?SecondLine">second line</a>)|,
q|<a href="http://senseis.xmp.net/?page=FourDieButSixLive">Four die but six live</a> (on the <a href="http://senseis.xmp.net/?ThirdLine">third line</a> or in the <a href="http://senseis.xmp.net/?Corner">corner</a> on the <a href="http://senseis.xmp.net/?SecondLine">second line</a>)|,
q|<a href="http://senseis.xmp.net/?page=FourIsFiveAndFiveIsEightAndSixIsTwelve">Four is five and five is eight and six is twelve</a>|,
q|The <a href="http://senseis.xmp.net/?page=CarpentersSquare">carpenters square</a> becomes <a href="http://senseis.xmp.net/?Ko">ko</a>|,
q|The <a href="http://senseis.xmp.net/?page=LGroup">L group</a> is dead|,
q|The <a href="http://senseis.xmp.net/?page=DoorGroup">door group</a> is dead|,
q|<a href="http://senseis.xmp.net/?page=StrangeThingsHappenAtTheOneTwoPoint">Strange things happen at the one two point</a>|,
q|<a href="http://senseis.xmp.net/?page=EyesWinSemeais">Eyes win semeais</a>|,
q|<a href="http://senseis.xmp.net/?page=CheckEscapeRoutesFirst">Check escape routes first</a>|,
q|<a href="http://senseis.xmp.net/?page=CaptureThreeToGetAnEye">Capture three to get an eye</a>|,
q|<a href="http://senseis.xmp.net/?page=OnlyEnclosedGroupsCanBeKilled">Only enclosed groups can be killed</a>|,
q|<a href="http://senseis.xmp.net/?page=RespondToAttachmentWithHane">Respond to attachment with hane</a>|,
q|<a href="http://senseis.xmp.net/?page=WedgeIfPossible">Wedge if possible</a>|,
q|<a href="http://senseis.xmp.net/?page=HaneAtTheHeadOfTwoStones">Hane at the Head of Two Stones</a>|,
q|<a href="http://senseis.xmp.net/?page=CrosscutThenExtend">Crosscut then extend</a>|,
q|<a href="http://senseis.xmp.net/?page=CaptureTheCuttingStones">Capture the cutting stones</a>|,
q|<a href="http://senseis.xmp.net/?page=BeginnersPlayAtari">Beginners play atari</a>|,
q|<a href="http://senseis.xmp.net/?page=TheEmptyTriangleIsBad">The empty triangle is bad</a>|,
q|<a href="http://senseis.xmp.net/?page=IkkenTobiIsNeverWrong">The one-point jump (ikken tobi) is never bad</a>|,
q|<a href="http://senseis.xmp.net/?page=DontTryToCutTheOnePointJump">Don&#039;t try to cut the one-point jump</a>|,
q|<a href="http://senseis.xmp.net/?ExtensionFromAWall">From one, two. From two, three</a>|,
q|<a href="http://senseis.xmp.net/?page=StrikeAtTheWaistOfTheKeima">Strike at the waist of the keima</a>|,
q|<a href="http://senseis.xmp.net/?page=CuttingRightThroughAKnightsMoveIsVeryBig">Cutting right through a knight&#039;s move is very big</a>|,
q|<a href="http://senseis.xmp.net/?page=DoNotPeepAtCuttingPoints">Do not peep at cutting points</a>|,
q|Two stones are five times harder to kill than one<a name='r3'></a><SUP>[<A HREF="#3">3</A>]</SUP>|,
q|<a href="http://senseis.xmp.net/?page=EvenAMoronConnectsAgainstAPeep">Even a moron connects against a peep</a>|,
q|If you have one stone on the third line in atari, <a href="http://senseis.xmp.net/?page=AddASecondStoneAndSacrificeBoth">add a second stone and sacrifice both</a>|,
q|<a href="http://senseis.xmp.net/?page=UseContactMovesForDefence">Use contact moves for defence</a>|,
q|<a href="http://senseis.xmp.net/?page=NeverIgnoreAShoulderHit">Never ignore a shoulder hit</a>|,
q|<a href="http://senseis.xmp.net/?page=TheBambooJointMayBeShortOfLiberties">The bamboo joint may be short of liberties</a>|,
q|<a href="http://senseis.xmp.net/?page=NetsAreBetterThanLadders">Nets are better than ladders</a>|,
q|<a href="http://senseis.xmp.net/?page=AnswerTheCappingPlayWithAKnightsMove">Answer the capping play with a knight&#039;s move</a>|,
q|<a href="http://senseis.xmp.net/?page=ApproachFromTheWiderSide">Approach from the wider side</a>|,
q|<a href="http://senseis.xmp.net/?page=BlockOnTheWiderSide">Block on the wider side</a>|,
q|<a href="http://senseis.xmp.net/?page=PlayAtTheCentreOfThreeStones">Play at the centre of three stones</a>|,
q|<a href="http://senseis.xmp.net/?page=AnswerKeimaWithKosumi">Answer keima with kosumi</a>|,
q|<a href="http://senseis.xmp.net/?page=FiveLibertiesForTacticalStability">Five liberties for tactical stability</a>|,
q|<a href="http://senseis.xmp.net/?page=CaptureStonesCaughtInALadderAtTheEarliestOpportunity">Capture stones caught in a ladder at the earliest opportunity</a>|,
q|<a href="http://senseis.xmp.net/?page=TwoHanesGainALiberty">Two hanes gain a liberty</a>|,
q|<a href="http://senseis.xmp.net/?page=TheStrongPlayerPlaysStraightTheWeakPlaysDiagonal">The strong player plays straight, the weak plays diagonal</a>|,
q|<a href="http://senseis.xmp.net/?page=ThereIsNoConnectionInTheCarpentersTriangle">There is no connection in the carpenter&#039;s triangle</a>|,
q|Jump out once and then make eyes|,
q|<a href="http://senseis.xmp.net/?page=UrgentPointsBeforeBigPoints">Urgent points before big points</a>|,
q|<a href="http://senseis.xmp.net/?page=DontThrowAnEggAtAWall">Don&#039;t throw an egg at a wall</a>|,
q|<a href="http://senseis.xmp.net/?page=PlayAwayFromThickness">Play away from thickness</a>|,
q|<a href="http://senseis.xmp.net/?page=DontUseThicknessToMakeTerritory">Don&#039;t use thickness to make territory</a>|,
q|<a href="http://senseis.xmp.net/?page=MakeTerritoryWhileAttacking">Make territory while attacking</a>|,
q|<a href="http://senseis.xmp.net/?page=APonnukiIsWorthThirtyPoints">A ponnuki is worth thirty points</a>|,
q|<a href="http://senseis.xmp.net/?page=MakeAFistBeforeStriking">Make a fist before striking</a>|,
q|<a href="http://senseis.xmp.net/?page=DoNotDefendTerritoriesOpenOnTwoSides">Do not defend territories open on two sides</a> (Don't try to enclose when you have an <a href="http://senseis.xmp.net/?OpenSkirt">open skirt</a>)|,
q|<a href="http://senseis.xmp.net/?page=AttachToTheStrongerStoneInAPincer">Attach to the stronger stone in a pincer</a>|,
q|<a href="http://senseis.xmp.net/?page=MakeAFeintToTheEastWhileAttackingInTheWest">Make a feint to the east while attacking in the west</a>|,
q|<a href="http://senseis.xmp.net/?page=SacrificePlumsForPeaches">Sacrifice plums for peaches</a>|,
q|<a href="http://senseis.xmp.net/?page=ARichManShouldNotPickQuarrels">A rich man should not pick quarrels</a>|,
q|<a href="http://senseis.xmp.net/?page=PlayKikashiBeforeLiving">Play kikashi before living</a>|,
q|<a href="http://senseis.xmp.net/?page=KeshiIsWorthAsMuchAsAnInvasion">Keshi is worth as much as an invasion</a>|,
q|<a href="http://senseis.xmp.net/?page=InvadeAMoyoOneMoveBeforeItBecomesTerritory">Invade a moyo one move before it becomes territory</a>|,
q|<a href="http://senseis.xmp.net/?page=DontAttachWhenAttacking">Don&#039;t attach when attacking</a>|,
q|<a href="http://senseis.xmp.net/?page=MakeWeakWalkAlongWeak">Make weak walk along weak</a>, Korean proverb|,
q|<a href="http://senseis.xmp.net/?page=FiveGroupsMightLiveButTheSixthWillDie">Five groups might live but the sixth will die</a>|,
q|<a href="http://senseis.xmp.net/?page=BigDragonsNeverDie">Big dragons never die</a>|,
q|<a href="http://senseis.xmp.net/?page=GrabTheShapePointsInKikashi">Grab the shape points in kikashi</a>|,
q|<a href="http://senseis.xmp.net/?page=GiveYourOpponentWhatHeWants">Give your opponent what he wants</a>|,
q|<a href="http://senseis.xmp.net/?page=AvoidIppoji">Avoid ippoji</a>|,
q|<a href="http://senseis.xmp.net/?page=DontTradeADollarForAPenny">Don&#039;t trade a dollar for a penny</a>|,
q|<a href="http://senseis.xmp.net/?page=ThereAreNoKoThreatsInTheOpening">There are no ko threats in the opening</a>|,
q|<a href="http://senseis.xmp.net/?page=StrengtheningYourOwnWeakGroupMakesYourOpponentsWeaker">Strengthening your own weak group makes your opponent&#039;s weaker</a>|,
q|<a href="http://senseis.xmp.net/?page=OnlyAfterThe10thPunchWillYouSeeTheFist">Only after the 10th punch will you see the fist</a> - and only after the 20th will you block it.|,
q|<a href="http://senseis.xmp.net/?page=DontTouchWeakStones">Don&#039;t touch weak stones</a>|,
q|<a href="http://senseis.xmp.net/?page=NeverUpsetYourStarPointStones">Never upset your star-point stones</a>|,
q|<a href="http://senseis.xmp.net/?page=UseTheCornerToConquerTheSide">Use the corner to conquer the side</a>|,
q|<a href="http://senseis.xmp.net/?page=GreedForTheWinTakesTheWinAway">Greed for the win takes the win away</a>|,
q|<a href="http://senseis.xmp.net/?HighAndLowMoves">High move (4th line) for influence, low move (3rd line) for territory</a>|,
q|<a href="http://senseis.xmp.net/?page=IfYouHaveLostFourCornersResign">If you have lost four corners, resign</a>|,
q|<a href="http://senseis.xmp.net/?page=DontPushFromBehind">Don&#039;t push from behind.</a>|,
q|<a href="http://senseis.xmp.net/?page=DontPushAlongTheFifthLine">Don&#039;t push along the fifth line</a><a name='r4'></a><SUP>[<A HREF="#4">4</A>]</SUP>.|,
q|<a href="http://senseis.xmp.net/?TheSecondLineIsTheRouteToDefeat">Don't push along the second line</a>.|,
q|<a href="http://senseis.xmp.net/?page=ProverbsDoNotApplyToWhite">Proverbs do not apply to White</a>|,
q|<a href="http://senseis.xmp.net/?page=IfItHasANameKnowIt">If It Has a Name Know It</a>|,
q|<a href="http://senseis.xmp.net/?page=DontTryToWeaselAWinOutOfAProverb">Don&#039;t try to weasel a win out of a proverb.</a>|,
q|Proverbs only apply to Kyu players|,
q|<a href="http://senseis.xmp.net/?page=UseGoToMeetFriends">Use Go to meet friends</a> (&quot;Yi Qi Hui You&quot;)|,
q|<a href="http://senseis.xmp.net/?page=LearningJosekiLosesTwoStonesStrength">Learning Joseki loses two stones strength</a>|,
q|<a href="http://senseis.xmp.net/?page=BlackShouldResignIfOnePlayerHasFourCorners">Black should resign if one player has four corners</a>|,
q|<a href="http://senseis.xmp.net/?page=IfYouDontKnowLaddersDontPlayGo">If you don&#039;t know ladders, don&#039;t play go</a>|,
q|<a href="http://senseis.xmp.net/?page=YouCanPlayGoButDontLetGoPlayYou">You can play Go but don&#039;t let Go play you</a>|,
q|<a href="http://senseis.xmp.net/?page=IfYouDontLikeKoDontPlayGo">If you don&#039;t like Ko don&#039;t Play Go</a>|,
q|<a href="http://senseis.xmp.net/?page=LoseYourFirst50GamesAsQuicklyAsPossible">Lose Your First 50 Games as Quickly as Possible</a>|,
q|<a href="http://senseis.xmp.net/?page=YouNeedHalfThePoints1">You need half the points + 1</a>|,
q|<a href="http://senseis.xmp.net/?page=FiveLibertiesForTacticalStability">Five Liberties for Tactical Stability</a>|,
q|<a href="http://senseis.xmp.net/?page=WhenInDoubtTenuki">When in doubt, tenuki</a>|,
q|<a href="http://senseis.xmp.net/?page=NeverMakeHollowKoThreats">Never make hollow ko threats</a>|,
q|Trying to achieve light and airy gamestyle ends up blown away|,
q|If you have 30 minutes, use them|,


#humorous
q|<a href="http://senseis.xmp.net/?CutFirstThinkLater">Cut first, think later</a>.|,
q|Never try to smoke a bamboo joint.|,
q|Hitting your opponent on the head with a wooden stick is <a href="http://senseis.xmp.net/?Vulgar">vulgar</a> style.|,
q|When you have a train to catch, resign.|,
q|Strange things happen at the <a href="http://senseis.xmp.net/?63Point">17-14 point</a>.|,
q|The first line is the edge of the board.|,
q|Play fast, lose fast. <a href="http://senseis.xmp.net/?WastingTimeInALostGame">Play slow, lose slow</a>.|,
q|The empty sake bottle shape is negative.|,
q|Learn the wallet-stealing tesuji.|,
q|Learn the Tenuki tesuji.|,
q|Learn the <a href="http://senseis.xmp.net/?ThrowingTheBoardAgainstTheWallDentingTheWallAndTheBoardPriorToUppercuttingYourOpponent">nuclear tesuji</a>.|,
q|Learn the <a href="http://senseis.xmp.net/?Makemashita">makemashita</a> tesuji.|,
q|Strong players walk straight.|,
q|The strongest player knows the way to the restaurant.|,
q|The <a href="http://senseis.xmp.net/?Wall">walls</a> may have ears, but they don't have eyes.|,
q|If throwing in doesn't work, try throwing up.|,
q|Play <a href="http://senseis.xmp.net/?Kikashi">kikashi</a> before you forget.|,
q|<a href="http://senseis.xmp.net/?Tenuki">Tenuki</a> before you forget.|,
q|<a href="http://senseis.xmp.net/?DeathInGote">Don't die with gote</a>.|,
q|<a href="http://senseis.xmp.net/?MakeAFeintToTheEastWhileAttackingInTheWest">Faint in the east before attacking the west</a>|,
q|Lose 100 stones as quickly as you can.|,
q|Since everything works in <a href="http://senseis.xmp.net/?GoTheory">Theory</a>, let's move there.|,
q|A stone on the board is worth two in the bowl.|,
q|An oddity, an oddity, always an oddity.|,
q|<a href="http://senseis.xmp.net/?GiveMeLiberties">Give me liberties, or give me death</a>.|,
q|It is better to dip your fingers in the coffee than to try to <a href="http://senseis.xmp.net/?Dohsuji#3">drink the stones</a>.|,
q|Know the <a href="http://senseis.xmp.net/?TimeStealingTesuji">time-stealing tesuji</a>.|,
q|White is always keeping the black stone down.|,
q|Don't play Go in the nude if you don't have the stones.|,
q|Even a moron peeps at an <a href="http://senseis.xmp.net/?OpenSkirt">open skirt</a>.|,
q|The 9 stone <a href="http://senseis.xmp.net/?Handicap">handicap</a> does not qualify you for government disability.|,
q|Joseki addiction is a symptom of brain hormone deficit.|,
q|Don't play a time-stealing tesuji with your first move|,
q|<a href="http://senseis.xmp.net/?WhenInDoubtTenuki">When in doubt, tenuki</a>.|,
q|...When attacked, don't be in doubt.|,
q|Let him that is without gote place the first stone.|,
q|Reading Western authors on go loses four stones in strength.|,
q|Except when you are trying to understand <a href="http://senseis.xmp.net/?BillSpight">Bill Spight</a>; you either gain two stones or lose two stones in strength; it's <a href="http://senseis.xmp.net/?Miai">Miai</a>.|,
q|Read Hikaru and lose two stones in strength. <strong>Watch</strong> Hikaru and lose four.|,
q|<strong>Play</strong> Hikaru no Go and lose a <strong>lot</strong> more strength?|,
q|Whatever you do, you'll lose two stones in strength.|,
q|Apply any of these proverbs and lose two stones in strength for each, cumulative.|,
q|If at first you don't succeed, <a href="http://senseis.xmp.net/?OnlyAfterThe10thPunchWillYouSeeTheFist">die, die again</a>.|,
q|<a href="http://senseis.xmp.net/?WholeBoardThinking">Don't overlook the rest of the board</a>.  (Look it over, but don't overlook it! ;-)|,
q|Rules strength and playing strength are independent.|,
q|<a href="http://senseis.xmp.net/?IfItsWorthOnly15PointsPlayTenuki">Sacrifice every group of fewer than seven stones</a>!|,
q|It is better to die in good shape than to live in bad shape.|,
q|Strange things happen in byo-yomi.|,
q|Cut first, ask questions later.|,
q|Don't cut without thinking. Think first, then cut anyway.|,
q|Why cut your losses when you can cut <strong>everywhere</strong>!|,
q|Having two large groups is better than having one small group.|,
q|When the samurai verifies the presence of his head during fight, the dragon smiles.|,
q|Don't try to win. Try not to lose.|,
q|variation: Don't try to lose.|,
q|Don't play Go and feel bad; play bad Go and feel good.|,
q|Peep first, ask questions later.|,
q|Never hesitate to play bad shape.|,
q|An empty triangle is only bad shape when it's bad shape.|,
q|Drive your opponent up the wall.|,
q|Bad shape is never good shape unless worse shape comes along.|,
q|No answer is also an answer.|,
q|Use ladders to climb the walls.|,
q|Dame is worth ten points.|,
q|Seen from a sufficient distance, the black and white stones of any go game form their own unique shade of grey.|,
q|Do not pass.  Do not collect $200.|,
q|<a href="http://senseis.xmp.net/?GoIsLikeGolf">Go is like golf</a>|,
q|Don't play a <a href="http://senseis.xmp.net/?Mukou">gote ko threat</a>.|,
q|It's only a ko threat if there's a good response to it.|,
q|Know and avoid the beer-spilling tesuji.|,
q|If you can't think of a good reason not to make a particular play, <strong>don't make it</strong>! |,
q|A good procrastination is worth 30 passes.|,
q|Cash in your aji.  Play aji-cashy.|,
q|You can't win a <a href="http://senseis.xmp.net/?Semeai">semeai</a> against a group with two <a href="http://senseis.xmp.net/?Eye">eye</a>s (alternatively: <a href="http://senseis.xmp.net/?StupidMoves#1">Two eyes against one eye is a fight about nothing</a>)|,
q|Answer the crappy play with diabolic laughter.|,
q|If you obey no proverbs then resign.  If you obey all proverbs then resign.|,
q|If you obey ANY proverbs on this page, you might consider resigning too!|,
q|All Go Proverbs lie. - Godel|,
q|White stones never die, they just get sacrificed|,
q|<a href="http://senseis.xmp.net/?ALittleKnowledgeIsADangerousThing">A Little Knowledge Is A Dangerous Thing</a>.|,
q|Better the tesuji you know than the joseki you don't|,
q|Learn the flatulence tesuji.|,
q|Learn the cleavage tesuji.|,
q|Learn tesuji.|,
q|You connect, I connect, we connect.|,
q|The more you try to prevent something from happening, the more likely it is to happen.|,
q|People who play Go in glass houses shouldn't throw stones.|,
q|The pear shape is negative.|,
q|Remember, it's all fun and games until someone loses an eye.|,
q|To peep into a tigers mouth is to invite death|,
q|Your opponent's best move is the one you overlooked|,
q|Why play ko if you can die without one?|,
q|Strange things happen in the third round.|,
q|In the land of the blind, <a href="http://senseis.xmp.net/?EyeVersusNoEyeCapturingRace">the one eyed man is king</a>.  Elsewhere, the best he can do is <a href="http://senseis.xmp.net/?Seki">seki</a>.|,
q|I can see the mistakes that caused me to lose.  I cannot see the mistakes that caused me not to win.|,
q|In a lightning game, don't make a <a href="http://senseis.xmp.net/?MolassesKo">molasses ko</a>.|,
q|With enough thickness, you can get away with anything.|,
q|When there is no vital point to strike at, invent one.|,
q|Any go proverb is right if it's cool enough.|,
q|Don't drink soda before your go lesson.|,
q|<a href="http://senseis.xmp.net/?IfYouDontHaveASenteMoveResign">If you don&#039;t have a sente move, resign</a>.|,
q|As is often the case, the point where you start noticing that White is kicking you around is actually much later than the causes of the kicking.|,
q|If you get to the point where you have to make choices between bad alternatives, then the problem is not here, but in earlier moves.|,
q|In the long run, it's not the great moves that win you the game, <a href="http://senseis.xmp.net/?TheFirstPlayerToBlunder">it's the bad ones that lose it</a>.|,
q|It is extremely important to unlearn such moves!|,
q|It is your responsibility to make sure that your opponent suffers if they have a <a href="http://senseis.xmp.net/?WeakGroup">weak group</a> on the board.|,
q|<a href="http://senseis.xmp.net/?LearningJosekiLosesTwoStonesStrength">Learning joseki loses two stones</a>; studying joseki gains four stones|,
q|Never start a fight unless you are losing|,
q|The center has become as white as Himalaya snows.|,
q|The challenge in Go is to find moves that accomplish several things at one time. We amateurs often end up playing moves that accomplish none of our objectives.|,
q|This is another move that is worse than passing.|,
q|White asks being cut, so you should do him the favor!|,
q|The pro verb is win.|,
q|The three most important words in go are: &quot;knowing how to count&quot;.|,
q|Passing is the ultimate tenuki.|,
q|Old go players never die, they just pass.|,
q|Cut all over and let God sort 'em out.|,
q|Eat dragon eggs before they hatch.|,
q|Use a <a href="http://senseis.xmp.net/?CarpentersSquare">carpenter's square</a> on the 2x4 board.|,
q|If you cannot find a good move, try the <a href="http://senseis.xmp.net/?404NotFound">404 enclosure</a>.|,
q|White is usually trying to kill a larger group than Black is trying to save.|,
q|Many opponents stones fill the farmers hat.|,
q|One stone does not make a <a href="http://senseis.xmp.net/?Shimari">shimari</a>.|,
q|When in atari, tenuki.|,
q|If Black has all 5 corners, resign|,
q|There is damezumari in the 1-1 point. <a href="http://senseis.xmp.net/?GeorgeCaplan">George Caplan</a>|,
q|White groups never die, they just get sacrificed|,
q|Repeating mistakes creates a sense of familiarity ... [ChrisWKS]|,
q|The difference between a rip off and a tesuji is often insignificant|,
q|Don't surround thickness with territory.|,
q|If an infinite amount of large monkeys jumps from a <a href="http://senseis.xmp.net/?Submarine">submarine</a>, it's still gote.|,
q|<a href="http://senseis.xmp.net/?OneNuki">One-nuki</a> is better than no-nuki at all.|,
q|Go is so incredibly complex that it begins to approximate actually doing something.|,
q|Do not play go with lodestones.|,
q|The 3-3 invasion is always premature.|,
q|Run before dying.|,
q|Even blind dragons breath fire.|,
q|Eat well, sleep well, and gain two stones|,
q|Cut out carbs and lose one stone, maybe two.|,
q|I never play sente moves, its a waste of ko threats.|,
q|I am in your <a href="http://senseis.xmp.net/?Base">base</a>, stealing your <a href="http://senseis.xmp.net/?EyeSpace">eyes</a>.|,
q|Apply the <a href="http://senseis.xmp.net/?BlackholeTesuji">Blackhole Tesuji</a> and gain 2 stones in strength.|,
q|Drop the bowls in a dark room, lose 20 stones.|,
);

sub random_proverb{
   return $proverbs[int rand (scalar @proverbs)];
}
