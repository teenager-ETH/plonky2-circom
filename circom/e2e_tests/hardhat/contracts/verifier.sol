//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.11;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
             6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
             10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [18372901375513044820355357972478283165323678193655481490194610443617683917675,
             6141408384442025411718902089277083473722666793057519867820024390338128518377],
            [10502484549563301610567858316875257507583916842134859935615368274507783109598,
             4109479948475280161848803880676809072228150064200304851004036568612016490807]
        );
        vk.IC = new Pairing.G1Point[](69);
        
        vk.IC[0] = Pairing.G1Point( 
            410927766924209673722282801593184556574559887736732978333498356972818525710,
            19202811902833226016526819233397425301121048721565014199168115472753697160277
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            10210696453932132521288638384870365124501036303433880688761988499781850084285,
            7045924713368469913682980634205636588775603573040437908934532143346190080872
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            2196602831657633723281957881392716821380936801463301582341391864915562132509,
            10981221994024026932657709663707156274563152280169752751672846907657777473334
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            18729743358967660227550008882618879102560776908640956358266373087812261836558,
            20329560929070817924364361435656992701027628031992655741138422296324565810469
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            18629065192361255060681079397952816270259714577919417046725736186251881833190,
            19157377948810238016035252902418839935458916699055713566271663691860172943193
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            7850041009115732714331086890247231554879313026217049734416895788083146331411,
            13214352207575183622150748761364271437206382747277923521096061016200632770345
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            6325703326689346336436821354564932001887978612238300848569388863112310938201,
            11262515400593528212447351664874881327404251821874173639379678630012640473907
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            21066237976630162759745721161152417832030369801520635956398784697071784500961,
            20345106789255572270884903809846288683571596960745026830287703797574185204878
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            18801741876185697829671121792097397934909192718167524434145754646989508994762,
            787706365054198734338243074392039474621254698198627740276632189915061370687
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            12776421825180734415559927347094285488245799332020899765456322886176173084440,
            4662482839727665890314751415229621316237605845584350604802654959129135055634
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            16854743812612985688749147254292325541072796262413020489881403602226451611988,
            11217050332480114298986897697861109761849832682841152008074490193023973591196
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            7914833199845805446456176287678024503993399939601078801718493720045063497479,
            14083742146906359440754497790039090364293734956427421263890847012178310722687
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            11507956577910380219861611444388658055208678855254600806763092861049489195214,
            21816674912117827614215892998777542291787547092191938571412169453296828261304
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            8812622228393955648550217476015443170641094447068620223191208788351356795600,
            18384314436819252307184613428783550809583040631750039873614135261111310724984
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            2544684862834288957380022451213483975663211739835564602733280203733111762454,
            16384838848808627337752049736711478512655449060417662132415219191060114137900
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            14186319788011026156512018373705875193440505748317015895026934432970715994616,
            3644752694836032367309866332955537014007893786353104143446293436921255699609
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            1051248401528337683400592363547159305996868822646296761712647146163978645103,
            8824629509266088862288660216924062331930060552575862166733448107605836039744
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            1053620366003948415197623460754683334551528041187745732125784392639855069641,
            5615859448949233901089297028724907487276770333976153810089793422230469519997
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            9419678681020652750539192494951313685266810510941248332467966460374086599303,
            15721827277985921375589254493162516777505796600348893757473312520909048272574
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            10662647689706169855661632656477759211900414402997406017228526393207425991612,
            9655797396865447947755492040592723686992786949504759462377626807220200104290
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            3490525798777680642181578335554840290818375914703226918460528987356669483816,
            1111374949833127207087384346110682886984908988136855864729612398209298998473
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            2392684413217617265512930453395753844166612906561496552831282647095266915136,
            13221423174882071101429595668762486181112298797145837854838742082884852216169
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            7386567674644136223870019436048454462803824282085201692412914671811284249551,
            7973356479230900387442178381920974744834099365401682410903101012570601320699
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            1222615799071499979536238559521376930599980745567455147092201618136799596812,
            15185881000772218601622009244417787218267702756931104025004292538078639756454
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            155158180292268415959529463634275403480304033863412149440425262582666967216,
            19663761917245105235663026443572016821353149046955328498317021814844963048831
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            364988450703655131140719334688495707045548661421350969984152723241850884402,
            8759701444268455377338243365090990359997154954871983774731842810873722926969
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            16205331673608484942334943941179321233610918411244842298608011074435628041603,
            9853593927707277615609648007665348402618980298685987592001929747131088664346
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            6372344556544388921767397606569229217546511437895709488554602362391150612217,
            4992493159385767508430176453754204484966348599598884541970719528420051486805
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            15711619692931600785292740409611940881634097953625990239845427585795965534710,
            11850405462607929945367141385281996099364815836474350612078908834542491008071
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            17681637028529776957272042466001739558002089549788915595540012418232314865785,
            4213507954472003251589104116561033683016288872950343009315739642554749476971
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            15192788847513443720514258761061082867550004512862989163175418760320316815572,
            6392748993251206905981229653139812421749440050293712483776040117817867734608
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            16759176602277429468781513544133602635964824561855150020559297640680557884295,
            21788615477739611588773313580462135563416574226721144832488463436104962462890
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            11164294178414320792612942130306165025052756141397313505722030106631912483978,
            13136452739089348400060039440357149082053095841755225831735631718905583423675
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            6357750172283301706923160844762545880892585462157625520649656800849612021124,
            12607729515696085550805192178312349907483821316032339353412797934526154510841
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            12314593043978541851404148931958598668189211877439056069495437256686299601381,
            5452226744841938724722950183560649466057018573931774705354346814085213408259
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            17465488660671820324325824507299405007301859907250844383605059177179285892174,
            18835328231358695348238745424991374170305552946899889695137309954190025830410
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            6087995026132261053341097428862662591690006860891204187039609524877555222133,
            14308920324851877620506056575566103493684897073936883912451251639766667271481
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            15837057182565987164827806137734143855530231874377616299132751284011219897247,
            16067520555849239883792991573079770698677418736603634827572919460085601048837
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            9746656886177551561734667455590257195630148008684258189452008399251390335392,
            5329578077865075550333821371189240555943181215315850231346212767262109107149
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            21377060779725323615315451393287515174244838635179241040168031319166967591839,
            12967239482300251307144934492255779626365674005532578145373833392722244296269
        );                                      
        
        vk.IC[40] = Pairing.G1Point( 
            10333680113354813134349141368895804328521381463520922648073852738712554873488,
            11417739499404387458371936684126967739199247198962037762335370653355172366919
        );                                      
        
        vk.IC[41] = Pairing.G1Point( 
            13573629679880796400967517051265594712739474404210934016343922293520596635198,
            6076077326006503185026625956773236150611026744076714039441543764080204638547
        );                                      
        
        vk.IC[42] = Pairing.G1Point( 
            1325794108955538644589356701863735952718656720044634111775549494720953607980,
            15342520453450798143723091964473053662263616569207893670678523888301903615522
        );                                      
        
        vk.IC[43] = Pairing.G1Point( 
            2692348597280964411636751394663677714983784047861403173302305724674630417624,
            3517438190060901488119228910751612521920528215532803133597275481042497976578
        );                                      
        
        vk.IC[44] = Pairing.G1Point( 
            12522766952346470614596595519898331330397882394121763115512219585508497983447,
            3987336688484635535657479902315306600084408999693825346387551712946921418573
        );                                      
        
        vk.IC[45] = Pairing.G1Point( 
            10949051300194044615136705955081035197592026583960264253142917632519352601804,
            13523115390164838486266227880808696574023563796377898379331808759063023050950
        );                                      
        
        vk.IC[46] = Pairing.G1Point( 
            21857455199297347599185346918869172863444212175567698876156402829144151049400,
            2199870155978776780999048561383889521429499703636074567534261957503934050755
        );                                      
        
        vk.IC[47] = Pairing.G1Point( 
            1249611682148174548587117104512527556990217090348456847430690517881923564699,
            19135572152573660313690968989485504354240002505385632275960908240221329573333
        );                                      
        
        vk.IC[48] = Pairing.G1Point( 
            30671793647099151655372249361366656690171080520045023991533566238021833654,
            8929625443015066567632534527923501660441431500366468406517110320283038908935
        );                                      
        
        vk.IC[49] = Pairing.G1Point( 
            2236009984999304670065030639495428774198068748957634100664745338623606769373,
            13296927172341605888514336695124011945314220955175773547772141509704008544428
        );                                      
        
        vk.IC[50] = Pairing.G1Point( 
            2174490230455572564657351964067759836489493825451002759549777187245710127478,
            1837953882812393357858142823049788344905235937195777773027699032341599987431
        );                                      
        
        vk.IC[51] = Pairing.G1Point( 
            825353542711052518883585566479261930366593770226717873049658090123558908580,
            20806216882493796860036101073514786678941658979354758850694239999013622330977
        );                                      
        
        vk.IC[52] = Pairing.G1Point( 
            3466331332958113037059140226540952948126491406910094543128773545061242294869,
            3469086551317766899661533856841432742182580601609100700676739471264216486542
        );                                      
        
        vk.IC[53] = Pairing.G1Point( 
            17719211420107381252343649566367363967795299850550646949518660426366062792268,
            21329647236493684353234936966316826719685835626423625883835736884726049056907
        );                                      
        
        vk.IC[54] = Pairing.G1Point( 
            6944595708078350743195782555834358273491456034625570099005138974674734237236,
            4043891100526257222513233532585887570151092338574976248717476071413699013430
        );                                      
        
        vk.IC[55] = Pairing.G1Point( 
            3461113369833127753848942169531313746156589520436268679636835437810263121655,
            7307331673953918473468936888045600231248727569029300919230534729284217695592
        );                                      
        
        vk.IC[56] = Pairing.G1Point( 
            16724916377880371081010855131126917832796471138004745480818765313329752178708,
            16310776769015115703529293353501647605011917106437252317528479286720946051623
        );                                      
        
        vk.IC[57] = Pairing.G1Point( 
            21373662963780645200224380727929093009220345571829851498508107772963966594504,
            6612708093542449495222782460711868712164117563335409659656405531064828586925
        );                                      
        
        vk.IC[58] = Pairing.G1Point( 
            17507746149685144848778601142061999593004699324871121964634495795645032966244,
            8948632932682453098364608374653515146560208608184495481645227732962325875838
        );                                      
        
        vk.IC[59] = Pairing.G1Point( 
            11664525429448287879261246475105487622580008265304121915527069235389002413370,
            10921003648910667592531769854494352675737863849430390580172777879377069263288
        );                                      
        
        vk.IC[60] = Pairing.G1Point( 
            8383597621020890183927074675279107581632789841799930095478935678634485288970,
            4546787344822866589369163123267755540250240064530130382485364565353319135937
        );                                      
        
        vk.IC[61] = Pairing.G1Point( 
            19839491682696939987580309612307228883955199294517051437916230789179287683660,
            344601388356219715190509900005769771175302572750198072968715696345458200729
        );                                      
        
        vk.IC[62] = Pairing.G1Point( 
            8480103574581453172658432313908107379000811433253004031476707771585094950334,
            3242059350322330280230705569139211161977492218372908244742181344242728706033
        );                                      
        
        vk.IC[63] = Pairing.G1Point( 
            13998729153305574621132303905570641411682785373566051484713925330044733692820,
            3564650020985275200416688325883713569659842322319416882367925919869760296598
        );                                      
        
        vk.IC[64] = Pairing.G1Point( 
            2918257644801496370409381606535562758561851981147790474935798113412440464944,
            7518555892868262005355546943405993406149471577780719034872988999175069423128
        );                                      
        
        vk.IC[65] = Pairing.G1Point( 
            11117310159561435095102066421599483624473225377820718672400069856702184165324,
            11739789951252287418904609632896752121010595354476108738676735812078717660952
        );                                      
        
        vk.IC[66] = Pairing.G1Point( 
            18068035450531326772168264940641362021883907611891374420168182465373107519210,
            2045291675583836852644801936616181578526999655408927974303147270012543858356
        );                                      
        
        vk.IC[67] = Pairing.G1Point( 
            21831574491965301782570211468238135527669296765998179573884667512415811880413,
            11068276295997798882892058738673363371099343521732879486428803416890599576716
        );                                      
        
        vk.IC[68] = Pairing.G1Point( 
            3231125601169094042865406882409881144721357949462017658508142714330238511863,
            14815539881618806238722023509422898578558645939484492872199853091409742318442
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[68] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
