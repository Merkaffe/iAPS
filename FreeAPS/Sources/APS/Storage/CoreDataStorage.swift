import CoreData
import Foundation
import SwiftDate
import Swinject

final class CoreDataStorage {
    let coredataContext = CoreDataStack.shared.persistentContainer.viewContext

    func fetchGlucose(interval: NSDate) -> [Readings] {
        var fetchGlucose = [Readings]()
        coredataContext.performAndWait {
            let requestReadings = Readings.fetchRequest() as NSFetchRequest<Readings>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            requestReadings.sortDescriptors = [sort]
            requestReadings.predicate = NSPredicate(
                format: "glucose > 0 AND date > %@", interval
            )
            try? fetchGlucose = self.coredataContext.fetch(requestReadings)
        }
        return fetchGlucose
    }

    func fetchLoopStats(interval: NSDate) -> [LoopStatRecord] {
        var fetchLoopStats = [LoopStatRecord]()
        coredataContext.performAndWait {
            let requestLoopStats = LoopStatRecord.fetchRequest() as NSFetchRequest<LoopStatRecord>
            let sort = NSSortDescriptor(key: "start", ascending: false)
            requestLoopStats.sortDescriptors = [sort]
            requestLoopStats.predicate = NSPredicate(
                format: "interval > 0 AND start > %@", interval
            )
            try? fetchLoopStats = self.coredataContext.fetch(requestLoopStats)
        }
        return fetchLoopStats
    }

    func fetchTDD(interval: NSDate) -> [TDD] {
        var uniqueEvents = [TDD]()
        coredataContext.performAndWait {
            let requestTDD = TDD.fetchRequest() as NSFetchRequest<TDD>
            requestTDD.predicate = NSPredicate(format: "timestamp > %@ AND tdd > 0", interval)
            let sortTDD = NSSortDescriptor(key: "timestamp", ascending: false)
            requestTDD.sortDescriptors = [sortTDD]
            try? uniqueEvents = coredataContext.fetch(requestTDD)
        }
        return uniqueEvents
    }

    func saveTDD(_ insulin: (bolus: Decimal, basal: Decimal, hours: Double)) {
        coredataContext.perform {
            let saveToTDD = TDD(context: self.coredataContext)
            saveToTDD.timestamp = Date.now
            saveToTDD.tdd = (insulin.basal + insulin.bolus) as NSDecimalNumber?
            let saveToInsulin = InsulinDistribution(context: self.coredataContext)
            saveToInsulin.bolus = insulin.bolus as NSDecimalNumber?
            // saveToInsulin.scheduledBasal = (suggestion.insulin?.scheduled_basal ?? 0) as NSDecimalNumber?
            saveToInsulin.tempBasal = insulin.basal as NSDecimalNumber?
            saveToInsulin.date = Date()
            try? self.coredataContext.save()
        }
    }

    func fetchTempTargetsSlider() -> [TempTargetsSlider] {
        var sliderArray = [TempTargetsSlider]()
        coredataContext.performAndWait {
            let requestIsEnbled = TempTargetsSlider.fetchRequest() as NSFetchRequest<TempTargetsSlider>
            let sortIsEnabled = NSSortDescriptor(key: "date", ascending: false)
            requestIsEnbled.sortDescriptors = [sortIsEnabled]
            // requestIsEnbled.fetchLimit = 1
            try? sliderArray = coredataContext.fetch(requestIsEnbled)
        }
        return sliderArray
    }

    func fetchTempTargets() -> [TempTargets] {
        var tempTargetsArray = [TempTargets]()
        coredataContext.performAndWait {
            let requestTempTargets = TempTargets.fetchRequest() as NSFetchRequest<TempTargets>
            let sortTT = NSSortDescriptor(key: "date", ascending: false)
            requestTempTargets.sortDescriptors = [sortTT]
            requestTempTargets.fetchLimit = 1
            try? tempTargetsArray = coredataContext.fetch(requestTempTargets)
        }
        return tempTargetsArray
    }

    func fetcarbs(interval: NSDate) -> [Carbohydrates] {
        var carbs = [Carbohydrates]()
        coredataContext.performAndWait {
            let requestCarbs = Carbohydrates.fetchRequest() as NSFetchRequest<Carbohydrates>
            requestCarbs.predicate = NSPredicate(format: "carbs > 0 AND date > %@", interval)
            let sortCarbs = NSSortDescriptor(key: "date", ascending: true)
            requestCarbs.sortDescriptors = [sortCarbs]
            try? carbs = coredataContext.fetch(requestCarbs)
        }
        return carbs
    }

    func fetchStats() -> [StatsData] {
        var stats = [StatsData]()
        coredataContext.performAndWait {
            let requestStats = StatsData.fetchRequest() as NSFetchRequest<StatsData>
            let sortStats = NSSortDescriptor(key: "lastrun", ascending: false)
            requestStats.sortDescriptors = [sortStats]
            requestStats.fetchLimit = 1
            try? stats = coredataContext.fetch(requestStats)
        }
        return stats
    }

    func fetchInsulinDistribution() -> [InsulinDistribution] {
        var insulinDistribution = [InsulinDistribution]()
        coredataContext.performAndWait {
            let requestInsulinDistribution = InsulinDistribution.fetchRequest() as NSFetchRequest<InsulinDistribution>
            let sortInsulin = NSSortDescriptor(key: "date", ascending: false)
            requestInsulinDistribution.sortDescriptors = [sortInsulin]
            try? insulinDistribution = coredataContext.fetch(requestInsulinDistribution)
        }
        return insulinDistribution
    }

    func fetchReason() -> Reasons? {
        var suggestion = [Reasons]()
        coredataContext.performAndWait {
            let requestReasons = Reasons.fetchRequest() as NSFetchRequest<Reasons>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            requestReasons.sortDescriptors = [sort]
            try? suggestion = coredataContext.fetch(requestReasons)
        }
        return suggestion.first
    }

    func fetchReasons(interval: NSDate) -> [Reasons] {
        var reasonArray = [Reasons]()
        coredataContext.performAndWait {
            let requestReasons = Reasons.fetchRequest() as NSFetchRequest<Reasons>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            requestReasons.sortDescriptors = [sort]
            requestReasons.predicate = NSPredicate(
                format: "date > %@", interval
            )
            try? reasonArray = self.coredataContext.fetch(requestReasons)
        }
        return reasonArray
    }

    func saveStatUploadCount() {
        coredataContext.performAndWait { [self] in
            let saveStatsCoreData = StatsData(context: self.coredataContext)
            saveStatsCoreData.lastrun = Date()
            try? self.coredataContext.save()
        }
        UserDefaults.standard.set(false, forKey: IAPSconfig.newVersion)
    }

    func saveVNr(_ versions: Version?) {
        if let version = versions {
            coredataContext.performAndWait { [self] in
                let saveNr = VNr(context: self.coredataContext)
                saveNr.nr = version.main
                saveNr.dev = version.dev
                saveNr.date = Date.now
                try? self.coredataContext.save()
            }
        }
    }

    func fetchVNr() -> VNr? {
        var nr = [VNr]()
        coredataContext.performAndWait {
            let requestNr = VNr.fetchRequest() as NSFetchRequest<VNr>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            requestNr.sortDescriptors = [sort]
            requestNr.fetchLimit = 1
            try? nr = coredataContext.fetch(requestNr)
        }
        return nr.first
    }

    func fetchMealPreset(_ name: String) -> Presets? {
        var presetsArray = [Presets]()
        var preset: Presets?
        coredataContext.performAndWait {
            let requestPresets = Presets.fetchRequest() as NSFetchRequest<Presets>
            requestPresets.predicate = NSPredicate(
                format: "dish == %@", name
            )
            try? presetsArray = self.coredataContext.fetch(requestPresets)

            guard let mealPreset = presetsArray.first else {
                return
            }
            preset = mealPreset
        }
        return preset
    }

    func fetchMealPresets() -> [Presets] {
        var presetsArray = [Presets]()
        coredataContext.performAndWait {
            let requestPresets = Presets.fetchRequest() as NSFetchRequest<Presets>
            requestPresets.predicate = NSPredicate(
                format: "dish != %@", "Empty" as String
            )
            try? presetsArray = self.coredataContext.fetch(requestPresets)
        }
        return presetsArray
    }

    func fetchOnbarding() -> Bool {
        var firstRun = true
        coredataContext.performAndWait {
            let requestBool = Onboarding.fetchRequest() as NSFetchRequest<Onboarding>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            requestBool.sortDescriptors = [sort]
            requestBool.fetchLimit = 1
            try? firstRun = self.coredataContext.fetch(requestBool).first?.firstRun ?? true
        }
        return firstRun
    }

    func saveOnbarding() {
        coredataContext.performAndWait { [self] in
            let save = Onboarding(context: self.coredataContext)
            save.firstRun = false
            save.date = Date.now
            try? self.coredataContext.save()
        }
    }

    func startOnbarding() {
        coredataContext.performAndWait { [self] in
            let save = Onboarding(context: self.coredataContext)
            save.firstRun = true
            save.date = Date.now
            try? self.coredataContext.save()
        }
    }

    func fetchSettingProfileName() -> String {
        fetchActiveProfile()
    }

    func fetchSettingProfileNames() -> [Profiles]? {
        var presetsArray: [Profiles]?
        coredataContext.performAndWait {
            let requestProfiles = Profiles.fetchRequest() as NSFetchRequest<Profiles>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            requestProfiles.sortDescriptors = [sort]
            try? presetsArray = self.coredataContext.fetch(requestProfiles)
        }
        return presetsArray
    }

    func fetchUniqueSettingProfileName(_ name: String) -> Bool {
        var presetsArray: Profiles?
        coredataContext.performAndWait {
            let requestProfiles = Profiles.fetchRequest() as NSFetchRequest<Profiles>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            requestProfiles.sortDescriptors = [sort]
            requestProfiles.predicate = NSPredicate(
                format: "uploaded == true && name == %@", name as String
            )
            try? presetsArray = self.coredataContext.fetch(requestProfiles).first
        }
        return (presetsArray != nil)
    }

    func saveProfileSettingName(name: String) {
        coredataContext.perform { [self] in
            let save = Profiles(context: self.coredataContext)
            save.name = name
            save.date = Date.now
            try? self.coredataContext.save()
        }
    }

    func migrateProfileSettingName(name: String) {
        coredataContext.perform { [self] in
            let save = Profiles(context: self.coredataContext)
            save.name = name
            save.date = Date.now
            save.uploaded = true
            try? self.coredataContext.save()
        }
    }

    func profileSettingUploaded(name: String) {
        var profile: String = name
        if profile.isEmpty {
            profile = "default"
        }

        // Avoid duplicates
        if !fetchUniqueSettingProfileName(name) {
            coredataContext.perform { [self] in
                let save = Profiles(context: self.coredataContext)
                save.name = profile
                save.date = Date.now
                save.uploaded = true
                try? self.coredataContext.save()
            }
        }
    }

    func activeProfile(name: String) {
        coredataContext.perform { [self] in
            let save = ActiveProfile(context: self.coredataContext)
            save.name = name
            save.date = Date.now
            save.active = true
            try? self.coredataContext.save()
        }
    }

    func checkIfActiveProfile() -> Bool {
        var presetsArray = [ActiveProfile]()
        coredataContext.performAndWait {
            let requestProfiles = ActiveProfile.fetchRequest() as NSFetchRequest<ActiveProfile>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            requestProfiles.sortDescriptors = [sort]
            try? presetsArray = self.coredataContext.fetch(requestProfiles)
        }
        return (presetsArray.first?.active ?? false)
    }

    func fetchActiveProfile() -> String {
        var presetsArray = [ActiveProfile]()
        coredataContext.performAndWait {
            let requestProfiles = ActiveProfile.fetchRequest() as NSFetchRequest<ActiveProfile>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            requestProfiles.sortDescriptors = [sort]
            try? presetsArray = self.coredataContext.fetch(requestProfiles)
        }
        return presetsArray.first?.name ?? "default"
    }

    func fetchLastLoop() -> LastLoop? {
        var lastLoop = [LastLoop]()
        coredataContext.performAndWait {
            let requestLastLoop = LastLoop.fetchRequest() as NSFetchRequest<LastLoop>
            let sortLoops = NSSortDescriptor(key: "timestamp", ascending: false)
            requestLastLoop.sortDescriptors = [sortLoops]
            requestLastLoop.fetchLimit = 1
            try? lastLoop = coredataContext.fetch(requestLastLoop)
        }
        return lastLoop.first
    }

    func insulinConcentration() -> (concentration: Double, increment: Double) {
        var conc = [InsulinConcentration]()
        coredataContext.performAndWait {
            let requestConc = InsulinConcentration.fetchRequest() as NSFetchRequest<InsulinConcentration>
            try? conc = coredataContext.fetch(requestConc)
        }
        let recent = conc.last
        return (recent?.concentration ?? 1.0, recent?.incrementSetting ?? 0.1)
    }

    func hasMigrated() -> Bool {
        var migration = [Migration]()
        coredataContext.performAndWait {
            let requestMigrationData = Migration.fetchRequest() as NSFetchRequest<Migration>
            try? migration = coredataContext.fetch(requestMigrationData)
        }
        return migration.first?.hasMigrated ?? false
    }

    func didMigrate() {
        coredataContext.perform { [self] in
            let migration = Migration(context: self.coredataContext)
            migration.hasMigrated = true
            try? self.coredataContext.save()
        }
    }

    func activeConfiguration() -> String? {
        var configuration = [Configurations]()
        coredataContext.performAndWait {
            let requestMigrationData = Configurations.fetchRequest() as NSFetchRequest<Configurations>
            let sort = NSSortDescriptor(key: "date", ascending: false)
            try? configuration = coredataContext.fetch(requestMigrationData)
        }

        guard let first = configuration.first, let string = first.name, first.active else {
            return nil
        }

        return string
    }

    func migration(oref0: Preferences, iAPS: FreeAPSSettings, configuration: String) -> Bool {
        coredataContext.perform { [self] in
            // OpenAPS Preferences
            let oref0Settings = Settings_ore0(context: self.coredataContext)
            oref0Settings.autosensMax = oref0.autosensMax as NSDecimalNumber
            oref0Settings.autosensMin = oref0.autosensMin as NSDecimalNumber
            oref0Settings.a52RiskEnable = oref0.a52RiskEnable
            oref0Settings.adjustmentFactor = oref0.adjustmentFactor as NSDecimalNumber
            oref0Settings.advTargetAdjustments = oref0.advTargetAdjustments
            oref0Settings.allowSMBWithHighTemptarget = oref0.allowSMBWithHighTemptarget
            oref0Settings.autotuneISFAdjustmentFraction = oref0.autotuneISFAdjustmentFraction as NSDecimalNumber
            oref0Settings.bolusIncrement = oref0.bolusIncrement as NSDecimalNumber
            oref0Settings.carbsReqThreshold = oref0.carbsReqThreshold as NSDecimalNumber
            oref0Settings.currentBasalSafetyMultiplier = oref0.currentBasalSafetyMultiplier as NSDecimalNumber
            oref0Settings.enableDynamicCR = oref0.enableDynamicCR
            oref0Settings.enableSMBAfterCarbs = oref0.enableSMBAfterCarbs
            oref0Settings.enableSMBAlways = oref0.enableSMBAlways
            oref0Settings.enableSMBWithCOB = oref0.enableSMBWithCOB
            oref0Settings.enableSMBAfterCarbs = oref0.enableSMBAfterCarbs
            oref0Settings.enableSMBWithTemptarget = oref0.enableSMBWithTemptarget
            oref0Settings.enableSMB_high_bg_target = oref0.enableSMB_high_bg_target as NSDecimalNumber
            oref0Settings.enableUAM = oref0.enableUAM
            oref0Settings.exerciseMode = oref0.exerciseMode
            oref0Settings.halfBasalExerciseTarget = oref0.halfBasalExerciseTarget as NSDecimalNumber
            oref0Settings.highTemptargetRaisesSensitivity = oref0.highTemptargetRaisesSensitivity
            oref0Settings.insulinPeakTime = oref0.insulinPeakTime as NSDecimalNumber
            oref0Settings.lowTemptargetLowersSensitivity = oref0.lowTemptargetLowersSensitivity
            oref0Settings.maxCOB = oref0.maxCOB as NSDecimalNumber
            oref0Settings.maxIOB = oref0.maxIOB as NSDecimalNumber
            oref0Settings.maxSMBBasalMinutes = oref0.maxSMBBasalMinutes as NSDecimalNumber
            oref0Settings.maxUAMSMBBasalMinutes = oref0.maxUAMSMBBasalMinutes as NSDecimalNumber
            oref0Settings.maxDailySafetyMultiplier = oref0.maxDailySafetyMultiplier as NSDecimalNumber
            oref0Settings.maxDeltaBGthreshold = oref0.maxDeltaBGthreshold as NSDecimalNumber
            oref0Settings.min5mCarbimpact = oref0.min5mCarbimpact as NSDecimalNumber
            oref0Settings.noisyCGMTargetMultiplier = oref0.noisyCGMTargetMultiplier as NSDecimalNumber
            oref0Settings.remainingCarbsCap = oref0.remainingCarbsCap as NSDecimalNumber
            oref0Settings.remainingCarbsFraction = oref0.remainingCarbsFraction as NSDecimalNumber
            oref0Settings.resistanceLowersTarget = oref0.resistanceLowersTarget
            oref0Settings.rewindResetsAutosens = oref0.rewindResetsAutosens
            oref0Settings.sensitivityRaisesTarget = oref0.sensitivityRaisesTarget
            oref0Settings.sigmoid = oref0.sigmoid
            oref0Settings.skipNeutralTemps = oref0.skipNeutralTemps
            oref0Settings.smbDeliveryRatio = oref0.smbDeliveryRatio as NSDecimalNumber
            oref0Settings.smbInterval = oref0.smbInterval as NSDecimalNumber
            oref0Settings.suspendZerosIOB = oref0.suspendZerosIOB
            oref0Settings.tddAdjBasal = oref0.tddAdjBasal
            oref0Settings.threshold_setting = oref0.threshold_setting as NSDecimalNumber
            oref0Settings.timestamp = oref0.timestamp
            oref0Settings.unsuspendIfNoTemp = oref0.unsuspendIfNoTemp
            oref0Settings.updateInterval = oref0.updateInterval as NSDecimalNumber
            oref0Settings.useCustomPeakTime = oref0.useCustomPeakTime
            oref0Settings.useNewFormula = oref0.useNewFormula
            oref0Settings.useWeightedAverage = oref0.useWeightedAverage
            oref0Settings.wideBGTargetRange = oref0.wideBGTargetRange

            // oref0Settings.curve
            switch oref0.curve {
            case .rapidActing:
                oref0Settings.curve = "rapidActing"
            case .ultraRapid:
                oref0Settings.curve = "ultraRapid"
            case .bilinear:
                oref0Settings.curve = "bilinear"
            }

            // iAPS settings
            let iAPSSettings = Settings_iAPS(context: self.coredataContext)
            iAPSSettings.addSourceInfoToGlucoseNotifications = iAPS.addSourceInfoToGlucoseNotifications
            iAPSSettings.allowAnnouncements = iAPS.allowAnnouncements
            iAPSSettings.animatedBackground = iAPS.animatedBackground
            iAPSSettings.carbsRequiredThreshold = iAPS.carbsRequiredThreshold as NSDecimalNumber
            iAPSSettings.closedLoop = iAPS.closedLoop
            iAPSSettings.debugOptions = iAPS.debugOptions
            iAPSSettings.delay = Int16(iAPS.delay)
            iAPSSettings.displayCalendarEmojis = iAPS.displayCalendarEmojis
            iAPSSettings.displayCalendarIOBandCOB = iAPS.displayCalendarIOBandCOB
            iAPSSettings.displayHR = iAPS.displayHR
            iAPSSettings.glucoseBadge = iAPS.glucoseBadge
            iAPSSettings.glucoseNotificationsAlways = iAPS.glucoseNotificationsAlways
            iAPSSettings.high = iAPS.high as NSDecimalNumber
            iAPSSettings.hours = Int16(iAPS.hours)
            iAPSSettings.individualAdjustmentFactor = iAPS.individualAdjustmentFactor as NSDecimalNumber
            iAPSSettings.isUploadEnabled = iAPS.isUploadEnabled
            iAPSSettings.localGlucosePort = Int16(iAPS.localGlucosePort)
            iAPSSettings.low = iAPS.low as NSDecimalNumber
            iAPSSettings.lowGlucose = iAPS.lowGlucose as NSDecimalNumber
            iAPSSettings.maxCarbs = iAPS.maxCarbs as NSDecimalNumber
            iAPSSettings.minuteInterval = Int16(iAPS.minuteInterval)
            iAPSSettings.oneDimensionalGraph = iAPS.oneDimensionalGraph
            iAPSSettings.overrideHbA1cUnit = iAPS.overrideHbA1cUnit
            iAPSSettings.profileID = iAPS.profileID
            iAPSSettings.rulerMarks = iAPS.rulerMarks
            iAPSSettings.skipBolusScreenAfterCarbs = iAPS.skipBolusScreenAfterCarbs
            iAPSSettings.smoothGlucose = iAPS.smoothGlucose
            iAPSSettings.timeCap = Int16(iAPS.timeCap)
            iAPSSettings.uploadGlucose = iAPS.uploadGlucose
            iAPSSettings.uploadStats = iAPS.uploadStats
            iAPSSettings.useAlarmSound = iAPS.useAlarmSound
            iAPSSettings.useAppleHealth = iAPS.useAppleHealth
            iAPSSettings.useAutotune = iAPS.useAutotune
            iAPSSettings.useCalendar = iAPS.useCalendar
            iAPSSettings.useFPUconversion = iAPSSettings.useFPUconversion
            iAPSSettings.useLocalGlucoseSource = iAPSSettings.useLocalGlucoseSource
            iAPSSettings.xGridLines = iAPS.xGridLines
            iAPSSettings.yGridLines = iAPS.yGridLines

            // Units
            switch iAPS.units {
            case .mmolL:
                iAPSSettings.units = "mmol"
            case .mgdL:
                iAPSSettings.units = "mg/dl"
            }

            // Configuration
            let configurations = Configurations(context: self.coredataContext)
            configurations.name = configuration
            configurations.date = Date.now
            configurations.active = true
            iAPSSettings.addToConfigurations(configurations)
            oref0Settings.addToConfigurations(configurations)

            do {
                try self.coredataContext.save()
            } catch {
                debug(.apsManager, "JSON settings couldn't be migrated to CoreData. Error: " + "\(error)")
                return false
            }
            // Migration completed
            debug(.apsManager, "JSON settings migrated successfully to CoreData.")
            return true
        }
    }
}
