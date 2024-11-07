const startTimeString = process.argv[2]
const [startDate, startMonth, startYear, startHours, startMinutes] = startTimeString.split(':').map(Number)

const targetTime = new Date()
targetTime.setUTCFullYear(startYear, startMonth - 1, startDate)
targetTime.setUTCHours(startHours + 5, startMinutes + 30, 0, 0)

const currentTime = new Date()
currentTime.setUTCSeconds(0) // we don't want precise time
currentTime.setUTCMilliseconds(0)

if (currentTime.getTime() === targetTime.getTime()) {
    console.log('[checkTime] time matches, now exiting with status 0 to make another runtime')
    process.exit(0)
} else {
    console.log('[checkTime] time doesn\'t match')
    console.log(`currentTime is ${currentTime}`)
    console.log(`targetTime is ${targetTime}`)
    process.exit(1)
}
