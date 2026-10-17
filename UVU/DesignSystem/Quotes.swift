import Foundation

/// Frases de UVU. Edita la lista libremente: agrega las tuyas, una por línea, en MAYÚSCULAS,
/// sin emojis. La frase del día (pantalla Hoy) rota sola, una distinta cada día.
enum Quotes {
    /// Frases del día, en inglés.
    static let all: [String] = [
        // De tus referencias
        "INSPIRED BY THE FEAR OF BEING AVERAGE.",
        "WHO ARE YOU WHEN NOBODY IS WATCHING?",
        "THE MORE YOU PUT IN, THE MORE YOU GET OUT.",
        "TAKE THAT RISK.",
        "LIFE BEGINS WHERE FEAR ENDS.",
        "COMFORT IS THE ENEMY OF GROWTH.",
        "IF YOU NEVER TRY, YOU'LL NEVER KNOW.",
        "STEP OUT.",
        "RISK IT.",
        "THERE IS NO RIGHT MOMENT. THERE IS YOU.",
        "LAST YEAR YOU SAID THIS YEAR.",
        "BE A DOER.",
        "EVERY REP COUNTS.",
        "DO.",
        "I DIDN'T WAKE UP TO BE AVERAGE.",
        "1% BETTER EVERY DAY.",
        "START WHERE YOU ARE. USE WHAT YOU HAVE. DO WHAT YOU CAN.",
        "IMPROVE YOURSELF. DON'T PROVE YOURSELF.",
        "MAKE YOURSELF A PRIORITY.",
        "HEALTH IS WEALTH.",
        "DO SOMETHING TODAY YOUR FUTURE SELF WILL THANK YOU FOR.",
        // Del mismo estilo
        "DISCIPLINE OVER MOTIVATION.",
        "NOBODY IS COMING. GET UP.",
        "EARN YOUR SLEEP.",
        "HARD CHOICES. EASY LIFE.",
        "DON'T NEGOTIATE WITH YOURSELF.",
        "MOTIVATION FADES. HABITS STAY.",
        "THE PAIN OF DISCIPLINE WEIGHS OUNCES. REGRET WEIGHS TONS.",
        "SHOW UP. ESPECIALLY WHEN YOU DON'T FEEL LIKE IT.",
        "SILENCE THE EXCUSES.",
        "YOU VS. YOU.",
        "QUIET WORK. LOUD RESULTS.",
        "FEEL THE FEAR. DO IT ANYWAY.",
        "DREAMS DON'T WORK UNLESS YOU DO.",
        "NO ZERO DAYS.",
        "OUTWORK YOUR EXCUSES.",
        "BE STRONGER THAN YOUR EXCUSES.",
        "ONE MORE REP.",
        "THE WORK IS THE REWARD.",
        "SMALL STEPS. EVERY DAY.",
        "CONSISTENCY BEATS INTENSITY.",
        "STOP WAITING. START DOING.",
        "IT NEVER GETS EASIER. YOU GET STRONGER.",
        "GROWTH IS UNCOMFORTABLE. GOOD.",
        "BUILD IN SILENCE.",
        "CHOOSE DISCOMFORT.",
        "EXCUSES DON'T BUILD ANYTHING.",
        "YOUR ONLY LIMIT IS YOU.",
        "EARNED. NEVER GIVEN.",
        "THE BEST TIME WAS YESTERDAY. THE NEXT BEST IS NOW.",
        "PROVE IT TO YOURSELF.",
        "GO THE EXTRA MILE. IT'S NEVER CROWDED.",
        "BECOME THE PERSON YOU KEEP DESCRIBING.",
        "DON'T WISH FOR IT. WORK FOR IT.",
        "DISCIPLINE IS SELF-RESPECT.",
        "STAY HARD ON YOURSELF. SOFT ON OTHERS.",
        "THE CLOCK IS TICKING. MOVE.",
        "WIN THE MORNING. WIN THE DAY.",
        "FALL SEVEN TIMES. STAND UP EIGHT.",
        "DO IT TIRED.",
    ]

    /// Estado vacío (listas sin contenido).
    static let empty = "NADA REGISTRADO. TODAVÍA."

    /// Al completar todos los hábitos del día.
    static let dayComplete = "HECHO. MAÑANA OTRA VEZ."

    /// La frase del día entre comillas tipográficas: “DO.”
    static func quotedOfTheDay(_ date: Date = .now) -> String {
        "“\(ofTheDay(date))”"
    }

    /// La misma frase durante todo el día; cambia a medianoche.
    static func ofTheDay(_ date: Date = .now) -> String {
        guard !all.isEmpty else { return "DO." }
        let day = AppCalendar.calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
