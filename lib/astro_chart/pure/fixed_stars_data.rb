# frozen_string_literal: true

module AstroChart
  module Pure
    # Fixed-star catalogue (J2000.0 / ICRS equatorial), transcribed verbatim from
    # Swiss Ephemeris sefstars.txt (Hipparcos/modern astrometry, < 0.1").
    # pm_ra = mu_alpha * cos(dec) (mas/yr); pm_dec = mu_delta (mas/yr). The
    # traditional nature/keyword are editorial (Robson, 1923), not astrometric.
    module FixedStarsData
      STARS = [
        { name: "Alpheratz",       ra:    2.096916, dec:   29.090431, pm_ra:   137.46, pm_dec:  -163.44, vmag:   2.06, nature: "Jupiter/Venus",   keyword: "independence, freedom, honor" },
        { name: "Baten Kaitos",    ra:   27.865145, dec:  -10.335036, pm_ra:    40.80, pm_dec:   -37.25, vmag:   3.72, nature: "Saturn",          keyword: "forced change, emigration, shipwreck" },
        { name: "Algenib",         ra:    3.308963, dec:   15.183594, pm_ra:     1.98, pm_dec:    -9.28, vmag:   2.84, nature: "Mars/Mercury",    keyword: "notoriety, drive, forcefulness" },
        { name: "Mirach",          ra:   17.433016, dec:   35.620558, pm_ra:   175.90, pm_dec:  -112.20, vmag:   2.05, nature: "Venus",           keyword: "beauty, love, harmony, devotion" },
        { name: "Sheratan",        ra:   28.660046, dec:   20.808031, pm_ra:    98.74, pm_dec:  -110.41, vmag:   2.65, nature: "Mars/Saturn",     keyword: "bodily injury, forceful energy" },
        { name: "Hamal",           ra:   31.793357, dec:   23.462418, pm_ra:   188.55, pm_dec:  -148.08, vmag:   2.01, nature: "Mars/Saturn",     keyword: "violence, independence, leadership" },
        { name: "Menkar",          ra:   45.569888, dec:    4.089739, pm_ra:   -10.41, pm_dec:   -76.85, vmag:   2.53, nature: "Saturn",          keyword: "disease, disgrace, throat trouble" },
        { name: "Algol",           ra:   47.042219, dec:   40.955647, pm_ra:     2.99, pm_dec:    -1.66, vmag:   2.12, nature: "Saturn/Jupiter",  keyword: "the Demon Star; misfortune, violence, loss of head" },
        { name: "Alcyone",         ra:   56.871152, dec:   24.105136, pm_ra:    19.34, pm_dec:   -43.67, vmag:   2.87, nature: "Moon/Jupiter/Mars", keyword: "the Weeping Sisters; vision, sorrow, notoriety" },
        { name: "Aldebaran",       ra:   68.980163, dec:   16.509302, pm_ra:    63.45, pm_dec:  -188.94, vmag:   0.86, nature: "Mars",            keyword: "the Watcher of the East; honor, courage, but violence" },
        { name: "Rigel",           ra:   78.634467, dec:   -8.201638, pm_ra:     1.31, pm_dec:     0.50, vmag:   0.13, nature: "Jupiter/Saturn/Mars", keyword: "success, technical/artistic skill, honor" },
        { name: "Bellatrix",       ra:   81.282764, dec:    6.349703, pm_ra:    -8.11, pm_dec:   -12.88, vmag:   1.64, nature: "Mars/Mercury",    keyword: "the Amazon Star; quick success then trouble" },
        { name: "Capella",         ra:   79.172328, dec:   45.997991, pm_ra:    75.25, pm_dec:  -426.89, vmag:   0.08, nature: "Mars/Mercury",    keyword: "inquisitiveness, love of learning, honors" },
        { name: "Betelgeuse",      ra:   88.792939, dec:    7.407064, pm_ra:    27.54, pm_dec:    11.30, vmag:   0.42, nature: "Mars/Mercury",    keyword: "martial honors, wealth, success" },
        { name: "Alnilam",         ra:   84.053389, dec:   -1.201919, pm_ra:     1.44, pm_dec:    -0.78, vmag:   1.69, nature: "Jupiter/Saturn",  keyword: "fleeting public honors" },
        { name: "Alhena",          ra:   99.427960, dec:   16.399280, pm_ra:    13.81, pm_dec:   -54.96, vmag:   1.92, nature: "Mercury/Venus",   keyword: "the Proud One; art, eminence, foot injury" },
        { name: "Sirius",          ra:  101.287155, dec:  -16.716116, pm_ra:  -546.01, pm_dec: -1223.07, vmag:  -1.46, nature: "Jupiter/Mars",    keyword: "the Dog Star; honor, fame, wealth, guardianship" },
        { name: "Canopus",         ra:   95.987958, dec:  -52.695661, pm_ra:    19.93, pm_dec:    23.24, vmag:  -0.74, nature: "Saturn/Jupiter",  keyword: "voyages, piety, but domestic difficulties" },
        { name: "Castor",          ra:  113.649472, dec:   31.888282, pm_ra:  -191.45, pm_dec:  -145.19, vmag:   1.58, nature: "Mercury",         keyword: "keen mind, sudden fame then loss, injury" },
        { name: "Pollux",          ra:  116.328958, dec:   28.026199, pm_ra:  -626.55, pm_dec:   -45.80, vmag:   1.14, nature: "Mars",            keyword: "the Wicked Boy; spirited, cruel, martial" },
        { name: "Procyon",         ra:  114.825498, dec:    5.224988, pm_ra:  -714.59, pm_dec: -1036.80, vmag:   0.37, nature: "Mercury/Mars",    keyword: "activity, sudden fortune then loss, dogs/danger" },
        { name: "Praesepe",        ra:  130.025000, dec:   19.983333, pm_ra:     0.00, pm_dec:     0.00, vmag:   3.70, nature: "Mars/Moon",       keyword: "the Beehive; blindness, disgrace, misfortune" },
        { name: "Asellus Borealis", ra:  130.821451, dec:   21.468500, pm_ra:  -103.51, pm_dec:   -39.48, vmag:   4.65, nature: "Mars/Sun",        keyword: "the Northern Ass; patience, courage, but violence" },
        { name: "Asellus Australis", ra:  131.171247, dec:   18.154306, pm_ra:   -17.67, pm_dec:  -229.26, vmag:   3.94, nature: "Mars/Sun",        keyword: "the Southern Ass; heroism, danger from beasts/fire" },
        { name: "Regulus",         ra:  152.092962, dec:   11.967209, pm_ra:  -248.73, pm_dec:     5.59, vmag:   1.40, nature: "Mars/Jupiter",    keyword: "the Royal Star / Cor Leonis; power, honor, downfall from success" },
        { name: "Zosma",           ra:  168.527089, dec:   20.523718, pm_ra:   143.42, pm_dec:  -129.88, vmag:   2.53, nature: "Saturn/Venus",    keyword: "the Backbone; melancholy, fear, victim/benefactor" },
        { name: "Denebola",        ra:  177.264910, dec:   14.572058, pm_ra:  -497.68, pm_dec:  -114.67, vmag:   2.13, nature: "Saturn/Venus",    keyword: "swift judgement, misfortune, regret, honors reversed" },
        { name: "Vindemiatrix",    ra:  195.544158, dec:   10.959150, pm_ra:  -273.80, pm_dec:    19.96, vmag:   2.79, nature: "Saturn/Mercury",  keyword: "the Widow-maker; falsity, depression, folly" },
        { name: "Spica",           ra:  201.298247, dec:  -11.161319, pm_ra:   -42.35, pm_dec:   -30.67, vmag:   0.97, nature: "Venus/Mars",      keyword: "the Virgin’s Ear of Wheat; brilliant fortune, gifts, honors" },
        { name: "Arcturus",        ra:  213.915300, dec:   19.182409, pm_ra: -1093.39, pm_dec: -2000.06, vmag:  -0.05, nature: "Mars/Jupiter",    keyword: "the Guardian; riches, honors through work, self-determination" },
        { name: "Alphecca",        ra:  233.671950, dec:   26.714693, pm_ra:   120.27, pm_dec:   -89.58, vmag:   2.24, nature: "Venus/Mercury",   keyword: "the Jewel of the Crown; honor, dignity, poetic/artistic" },
        { name: "Zuben Elgenubi",  ra:  222.719638, dec:  -16.041777, pm_ra:  -105.68, pm_dec:   -68.40, vmag:   2.75, nature: "Saturn/Mars",     keyword: "the Southern Scale; malevolence, disgrace, disease" },
        { name: "Zuben Eschamali", ra:  229.251724, dec:   -9.382914, pm_ra:   -98.10, pm_dec:   -19.65, vmag:   2.62, nature: "Jupiter/Mercury", keyword: "the Northern Scale; good fortune, high ambition, honor" },
        { name: "Unukalhai",       ra:  236.066976, dec:    6.425629, pm_ra:   133.84, pm_dec:    44.81, vmag:   2.63, nature: "Saturn/Mars",     keyword: "the Serpent’s Heart; misfortune, accidents, poison, chronic disease" },
        { name: "Antares",         ra:  247.351915, dec:  -26.432003, pm_ra:   -12.11, pm_dec:   -23.30, vmag:   0.91, nature: "Mars/Jupiter",    keyword: "the Watcher of the West / Scorpion Heart; rashness, honors then ruin" },
        { name: "Ras Algethi",     ra:  258.661909, dec:   14.390341, pm_ra:    -7.32, pm_dec:    36.07, vmag:   3.06, nature: "Mars/Venus/Mercury", keyword: "boldness, confidence, but recklessness" },
        { name: "Rasalhague",      ra:  263.733623, dec:   12.560037, pm_ra:   108.07, pm_dec:  -221.57, vmag:   2.07, nature: "Saturn/Venus",    keyword: "the Serpent-bearer; perversion, mental depravity, misfortune via others" },
        { name: "Sabik",           ra:  257.594529, dec:  -15.724907, pm_ra:    40.13, pm_dec:    99.17, vmag:   2.42, nature: "Saturn/Venus",    keyword: "wastefulness, lost energy, then success in evil" },
        { name: "Vega",            ra:  279.234735, dec:   38.783689, pm_ra:   200.94, pm_dec:   286.23, vmag:   0.03, nature: "Venus/Mercury",   keyword: "the Harp Star; refinement, artistry, idealism, changeableness" },
        { name: "Altair",          ra:  297.695827, dec:    8.868321, pm_ra:   536.23, pm_dec:   385.29, vmag:   0.76, nature: "Mars/Jupiter",    keyword: "the Eagle; bold, confident, sudden fortune, danger from reptiles" },
        { name: "Nunki",           ra:  283.816360, dec:  -26.296724, pm_ra:    15.14, pm_dec:   -53.43, vmag:   2.07, nature: "Jupiter/Mercury", keyword: "the Star of the Proclamation of the Sea; truthful, defensive" },
        { name: "Facies",          ra:  279.099750, dec:  -23.904750, pm_ra:     4.72, pm_dec:    -3.59, vmag:   6.17, nature: "Sun/Mars",        keyword: "the Face of the Archer; blindness, accidents, violence, leadership" },
        { name: "Deneb Algedi",    ra:  326.760184, dec:  -16.127287, pm_ra:   261.70, pm_dec:  -296.70, vmag:   2.83, nature: "Saturn/Jupiter",  keyword: "benevolence and sorrow, law, life-and-death power" },
        { name: "Sadalsuud",       ra:  322.889715, dec:   -5.571176, pm_ra:    18.77, pm_dec:    -8.21, vmag:   2.89, nature: "Saturn/Mercury",  keyword: "the Luckiest of the Lucky; occult troubles then triumph" },
        { name: "Sadalmelek",      ra:  331.445983, dec:   -0.319850, pm_ra:    18.25, pm_dec:    -9.39, vmag:   2.94, nature: "Saturn/Mercury",  keyword: "persecution, sudden destruction, but good with benefics" },
        { name: "Fomalhaut",       ra:  344.412693, dec:  -29.622237, pm_ra:   328.95, pm_dec:  -164.67, vmag:   1.16, nature: "Venus/Mercury",   keyword: "the Fish’s Mouth; a Royal Star; fame, occult, magical or spiritual" },
        { name: "Deneb",           ra:  310.357980, dec:   45.280339, pm_ra:     2.01, pm_dec:     1.85, vmag:   1.25, nature: "Venus/Mercury",   keyword: "the Swan’s Tail; ingenious, idealistic (Deneb Adige)" },
        { name: "Markab",          ra:  346.190223, dec:   15.205267, pm_ra:    60.40, pm_dec:   -41.30, vmag:   2.48, nature: "Mars/Mercury",    keyword: "honor, danger from fire/fever/blows, sorrow" },
        { name: "Scheat",          ra:  345.943573, dec:   28.082787, pm_ra:   187.65, pm_dec:   136.93, vmag:   2.42, nature: "Mars/Mercury",    keyword: "the Leg; extreme misfortune, suicide, drowning" },
        { name: "Achernar",        ra:   24.428523, dec:  -57.236753, pm_ra:    87.00, pm_dec:   -38.24, vmag:   0.46, nature: "Jupiter",         keyword: "the End of the River; success in public office, religion, beneficence" },
        { name: "Acrux",           ra:  186.649563, dec:  -63.099093, pm_ra:   -35.83, pm_dec:   -14.86, vmag:   0.81, nature: "Jupiter",         keyword: "the Southern Cross; religious devotion, ceremony, occult" },
        { name: "Hadar",           ra:  210.955856, dec:  -60.373035, pm_ra:   -33.27, pm_dec:   -23.16, vmag:   0.60, nature: "Venus/Jupiter",   keyword: "refinement, morality, position of power (Agena)" },
        { name: "Rigel Kentaurus", ra:  219.900850, dec:  -60.835619, pm_ra: -3608.00, pm_dec:   686.00, vmag:  -0.10, nature: "Venus/Jupiter",   keyword: "beneficence, friends, honor, self-analysis (Toliman)" },
        { name: "Diphda",          ra:   10.897379, dec:  -17.986606, pm_ra:   232.55, pm_dec:    31.99, vmag:   2.01, nature: "Saturn",          keyword: "the Second Frog; self-destruction by brute force, misfortune, illness" },
        { name: "Mirfak",          ra:   51.080709, dec:   49.861179, pm_ra:    23.75, pm_dec:   -26.23, vmag:   1.79, nature: "Jupiter/Saturn",  keyword: "boldness in adventure, martial honors" },
        { name: "Alkaid",          ra:  206.885157, dec:   49.313267, pm_ra:  -121.17, pm_dec:   -14.91, vmag:   1.86, nature: "Moon/Mercury",    keyword: "the Mourners / tail of the Bear; destruction, mourning, prison" },
        { name: "Dubhe",           ra:  165.931965, dec:   61.751035, pm_ra:  -134.11, pm_dec:   -34.70, vmag:   1.79, nature: "Mars",            keyword: "the Bear’s Back; martial spirit, destruction, arrogance" },
      ].freeze
    end
  end
end
