// Phase 1 (5G-LENA migration): co-channel interferer scenario.
//
// Goal of this file: demonstrate the fidelity property SWICS lacked --
// a constant interferer raises interference on the victim's resource blocks,
// producing a GRADED SINR drop and received-but-corrupted TBs (non-zero TBler /
// corrupt flag) rather than a binary reception gate. Sweep --jammerTxPowerDbm
// and read victim DL rows in RxPacketTrace.txt.
//
// Topology (single shared band -> co-channel):
//   gNB0 (victim)     at (0,0,10)   serves victimUE at (d,0,1.5)
//   gNB1 (interferer) at (0,30,10)  serves jamUE   at (d,0.5,1.5)  [co-located w/ victim]
// The interferer cell beamforms toward jamUE, which sits on top of the victim
// UE, so its energy lands on the victim. Both cells run saturating DL traffic
// on the same BWP. Raising gNB1 TxPower raises the interference floor.

#include "ns3/antenna-module.h"
#include "ns3/applications-module.h"
#include "ns3/core-module.h"
#include "ns3/flow-monitor-module.h"
#include "ns3/internet-module.h"
#include "ns3/mobility-module.h"
#include "ns3/nr-module.h"
#include "ns3/point-to-point-module.h"

#include <sstream>

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("McsDowngrade");

// Reactive MCS-aware jammer (idealized perfect-knowledge controller).
// It observes the victim UE's commanded DL MCS via the RxPacketTraceUe trace and
// toggles the interferer cell's Tx power: jam (high) while MCS >= threshold, silent
// (low) otherwise. This is selective, low-duty interference: jammed TBs are
// received-but-corrupted -> NACKs -> (with OLLA) the victim is trapped near the
// threshold while its CQI stays high. The jammer falls silent once MCS drops, so a
// working attack shows a LOW duty cycle.
class ReactiveJammer
{
  public:
    Ptr<NrGnbPhy> jammerPhy;
    double highPowerDbm{50.0};
    double lowPowerDbm{-50.0};
    uint8_t mcsThreshold{10};
    Time tick{MicroSeconds(100)};
    uint16_t victimRnti{1};
    uint64_t victimCellId{1};
    Time startTime;
    Time stopTime;

    uint8_t m_lastMcs{0};
    bool m_haveMcs{false};
    uint64_t m_onTicks{0};
    uint64_t m_totalTicks{0};

    void ObserveDl(RxPacketTraceParams p)
    {
        if (p.m_cellId == victimCellId && p.m_rnti == victimRnti)
        {
            m_lastMcs = p.m_mcs;
            m_haveMcs = true;
        }
    }

    void Start()
    {
        jammerPhy->SetTxPower(lowPowerDbm);
        Simulator::Schedule(startTime, &ReactiveJammer::Tick, this);
    }

    void Tick()
    {
        if (Simulator::Now() >= stopTime)
        {
            jammerPhy->SetTxPower(lowPowerDbm);
            return;
        }
        m_totalTicks++;
        if (m_haveMcs && m_lastMcs >= mcsThreshold)
        {
            jammerPhy->SetTxPower(highPowerDbm);
            m_onTicks++;
        }
        else
        {
            jammerPhy->SetTxPower(lowPowerDbm);
        }
        Simulator::Schedule(tick, &ReactiveJammer::Tick, this);
    }

    double DutyCycle() const
    {
        return m_totalTicks ? static_cast<double>(m_onTicks) / m_totalTicks : 0.0;
    }
};

int
main(int argc, char* argv[])
{
    // ---- parameters ----
    double victimTxPowerDbm = 30.0;
    double jammerTxPowerDbm = 30.0; // sweep this; low value ~= baseline
    bool jammerEnabled = true;
    double simTime = 1.0;       // seconds
    double appStart = 0.2;      // seconds
    double victimDistance = 20; // m from victim gNB
    double centralFrequency = 3.5e9;
    double bandwidth = 20e6;
    uint16_t numerology = 1;
    uint32_t packetSize = 1000;
    double lambda = 20000.0; // packets/s per flow (saturating)
    std::string simTag = "";
    bool useOlla = false;
    double ollaStep = 0.1;
    double ollaTargetBler = 0.1;
    bool reactive = false;
    uint32_t mcsThreshold = 10;
    double jammerHighPowerDbm = 50.0;
    double jammerLowPowerDbm = -50.0;
    bool urllc = false;          // victim uses periodic URLLC traffic instead of saturating
    double urllcPeriodMs = 1.0;  // PLC-style control period
    uint32_t urllcPacketSize = 1000;
    double deadlineMs = 2.0;     // latency budget for deadline-miss accounting

    CommandLine cmd(__FILE__);
    cmd.AddValue("victimTxPowerDbm", "Victim gNB Tx power (dBm)", victimTxPowerDbm);
    cmd.AddValue("jammerTxPowerDbm", "Interferer gNB Tx power (dBm)", jammerTxPowerDbm);
    cmd.AddValue("jammerEnabled", "Install the interferer cell traffic", jammerEnabled);
    cmd.AddValue("simTime", "Simulation time (s)", simTime);
    cmd.AddValue("victimDistance", "Victim UE distance from gNB (m)", victimDistance);
    cmd.AddValue("simTag", "Tag appended to trace file names", simTag);
    cmd.AddValue("useOlla", "Enable DL OLLA in the gNB scheduler", useOlla);
    cmd.AddValue("ollaStep", "OLLA step (MCS units)", ollaStep);
    cmd.AddValue("ollaTargetBler", "OLLA target BLER", ollaTargetBler);
    cmd.AddValue("reactive", "Use the reactive MCS-aware jammer (toggles interferer power)", reactive);
    cmd.AddValue("mcsThreshold", "Reactive jammer fires while victim MCS >= this", mcsThreshold);
    cmd.AddValue("jammerHighPowerDbm", "Reactive jammer ON power (dBm)", jammerHighPowerDbm);
    cmd.AddValue("jammerLowPowerDbm", "Reactive jammer OFF power (dBm)", jammerLowPowerDbm);
    cmd.AddValue("urllc", "Victim uses periodic URLLC traffic (else saturating)", urllc);
    cmd.AddValue("urllcPeriodMs", "URLLC inter-packet period (ms)", urllcPeriodMs);
    cmd.AddValue("urllcPacketSize", "URLLC packet size (bytes)", urllcPacketSize);
    cmd.AddValue("deadlineMs", "Latency budget for deadline-miss accounting (ms)", deadlineMs);
    cmd.Parse(argc, argv);

    // ---- nodes ----
    NodeContainer gnbNodes;
    gnbNodes.Create(2); // 0 = victim, 1 = interferer
    NodeContainer ueNodes;
    ueNodes.Create(2); // 0 = victim UE, 1 = interferer UE

    MobilityHelper mobility;
    mobility.SetMobilityModel("ns3::ConstantPositionMobilityModel");
    Ptr<ListPositionAllocator> pos = CreateObject<ListPositionAllocator>();
    pos->Add(Vector(0.0, 0.0, 10.0));            // gNB0 victim
    pos->Add(Vector(0.0, 30.0, 10.0));           // gNB1 interferer
    pos->Add(Vector(victimDistance, 0.0, 1.5));  // victim UE
    pos->Add(Vector(victimDistance, 0.5, 1.5));  // interferer UE (on top of victim)
    mobility.SetPositionAllocator(pos);
    mobility.Install(gnbNodes);
    mobility.Install(ueNodes);

    // ---- helpers ----
    Ptr<NrPointToPointEpcHelper> epc = CreateObject<NrPointToPointEpcHelper>();
    Ptr<IdealBeamformingHelper> bfHelper = CreateObject<IdealBeamformingHelper>();
    Ptr<NrHelper> nrHelper = CreateObject<NrHelper>();
    nrHelper->SetBeamformingHelper(bfHelper);
    nrHelper->SetEpcHelper(epc);

    // ---- spectrum: single band / CC / BWP ----
    BandwidthPartInfoPtrVector allBwps;
    CcBwpCreator ccBwpCreator;
    const uint8_t numCcPerBand = 1;
    CcBwpCreator::SimpleOperationBandConf bandConf(centralFrequency, bandwidth, numCcPerBand);
    OperationBandInfo band = ccBwpCreator.CreateOperationBandContiguousCc(bandConf);

    Ptr<NrChannelHelper> channelHelper = CreateObject<NrChannelHelper>();
    channelHelper->ConfigureFactories("UMi", "Default", "ThreeGpp");
    channelHelper->SetChannelConditionModelAttribute("UpdatePeriod", TimeValue(MilliSeconds(0)));
    channelHelper->SetPathlossAttribute("ShadowingEnabled", BooleanValue(false));
    channelHelper->AssignChannelsToBands({band});
    allBwps = CcBwpCreator::GetAllBwps({band});

    bfHelper->SetAttribute("BeamformingMethod", TypeIdValue(DirectPathBeamforming::GetTypeId()));
    epc->SetAttribute("S1uLinkDelay", TimeValue(MilliSeconds(0)));

    // antennas (isotropic elements, beamformed arrays)
    nrHelper->SetUeAntennaAttribute("NumRows", UintegerValue(2));
    nrHelper->SetUeAntennaAttribute("NumColumns", UintegerValue(4));
    nrHelper->SetUeAntennaAttribute("AntennaElement",
                                    PointerValue(CreateObject<IsotropicAntennaModel>()));
    nrHelper->SetGnbAntennaAttribute("NumRows", UintegerValue(4));
    nrHelper->SetGnbAntennaAttribute("NumColumns", UintegerValue(8));
    nrHelper->SetGnbAntennaAttribute("AntennaElement",
                                     PointerValue(CreateObject<IsotropicAntennaModel>()));

    // OLLA (ported) configuration on the gNB scheduler
    nrHelper->SetSchedulerAttribute("UseOlla", BooleanValue(useOlla));
    nrHelper->SetSchedulerAttribute("OllaStep", DoubleValue(ollaStep));
    nrHelper->SetSchedulerAttribute("OllaTargetBler", DoubleValue(ollaTargetBler));

    // ---- install devices ----
    NetDeviceContainer gnbDev = nrHelper->InstallGnbDevice(gnbNodes, allBwps);
    NetDeviceContainer ueDev = nrHelper->InstallUeDevice(ueNodes, allBwps);

    int64_t stream = 1;
    stream += nrHelper->AssignStreams(gnbDev, stream);
    stream += nrHelper->AssignStreams(ueDev, stream);

    // per-gNB numerology and Tx power
    NrHelper::GetGnbPhy(gnbDev.Get(0), 0)->SetAttribute("Numerology", UintegerValue(numerology));
    NrHelper::GetGnbPhy(gnbDev.Get(0), 0)->SetTxPower(victimTxPowerDbm);
    NrHelper::GetGnbPhy(gnbDev.Get(1), 0)->SetAttribute("Numerology", UintegerValue(numerology));
    // Static interferer power (used in constant-jammer mode; the reactive controller,
    // if enabled, overrides this dynamically below).
    NrHelper::GetGnbPhy(gnbDev.Get(1), 0)->SetTxPower(reactive ? jammerLowPowerDbm : jammerTxPowerDbm);

    // ---- core / internet ----
    auto [remoteHost, remoteHostAddr] = epc->SetupRemoteHost("100Gb/s", 2500, Seconds(0.0));
    InternetStackHelper internet;
    internet.Install(ueNodes);
    Ipv4InterfaceContainer ueIpIface = epc->AssignUeIpv4Address(NetDeviceContainer(ueDev));

    // explicit association: victim UE -> gNB0, interferer UE -> gNB1
    nrHelper->AttachToGnb(ueDev.Get(0), gnbDev.Get(0));
    nrHelper->AttachToGnb(ueDev.Get(1), gnbDev.Get(1));

    // ---- saturating DL traffic to each UE ----
    uint16_t dlPort = 1234;
    ApplicationContainer serverApps;
    ApplicationContainer clientApps;
    UdpServerHelper dlSink(dlPort);
    serverApps.Add(dlSink.Install(ueNodes));

    NrQosFlow flow(NrQosFlow::NGBR_LOW_LAT_EMBB);

    // victim flow (UE 0): periodic URLLC if requested, otherwise saturating
    {
        double victimInterval = urllc ? (urllcPeriodMs / 1000.0) : (1.0 / lambda);
        uint32_t victimPkt = urllc ? urllcPacketSize : packetSize;
        UdpClientHelper c;
        c.SetAttribute("MaxPackets", UintegerValue(0xFFFFFFFF));
        c.SetAttribute("PacketSize", UintegerValue(victimPkt));
        c.SetAttribute("Interval", TimeValue(Seconds(victimInterval)));
        c.SetAttribute("Remote",
                       AddressValue(addressUtils::ConvertToSocketAddress(
                           ueIpIface.GetAddress(0), dlPort)));
        clientApps.Add(c.Install(remoteHost));

        Ptr<NrQosRule> rule = Create<NrQosRule>();
        NrQosRule::PacketFilter pf;
        pf.localPortStart = dlPort;
        pf.localPortEnd = dlPort;
        rule->Add(pf);
        nrHelper->ActivateDedicatedQosFlow(ueDev.Get(0), flow, rule);
    }

    // interferer flow (UE 1) -- only if enabled
    if (jammerEnabled)
    {
        UdpClientHelper c;
        c.SetAttribute("MaxPackets", UintegerValue(0xFFFFFFFF));
        c.SetAttribute("PacketSize", UintegerValue(packetSize));
        c.SetAttribute("Interval", TimeValue(Seconds(1.0 / lambda)));
        c.SetAttribute("Remote",
                       AddressValue(addressUtils::ConvertToSocketAddress(
                           ueIpIface.GetAddress(1), dlPort)));
        clientApps.Add(c.Install(remoteHost));

        Ptr<NrQosRule> rule = Create<NrQosRule>();
        NrQosRule::PacketFilter pf;
        pf.localPortStart = dlPort;
        pf.localPortEnd = dlPort;
        rule->Add(pf);
        nrHelper->ActivateDedicatedQosFlow(ueDev.Get(1), flow, rule);
    }

    serverApps.Start(Seconds(appStart));
    clientApps.Start(Seconds(appStart));
    serverApps.Stop(Seconds(simTime));
    clientApps.Stop(Seconds(simTime));

    nrHelper->EnableTraces();

    // FlowMonitor for victim-flow latency / deadline-miss accounting
    FlowMonitorHelper flowmonHelper;
    NodeContainer endpoints;
    endpoints.Add(remoteHost);
    endpoints.Add(ueNodes);
    Ptr<FlowMonitor> monitor = flowmonHelper.Install(endpoints);
    monitor->SetAttribute("DelayBinWidth", DoubleValue(0.0005));

    // Reactive MCS-aware jammer (idealized perfect-knowledge controller)
    ReactiveJammer jammer;
    if (reactive)
    {
        jammer.jammerPhy = NrHelper::GetGnbPhy(gnbDev.Get(1), 0);
        jammer.highPowerDbm = jammerHighPowerDbm;
        jammer.lowPowerDbm = jammerLowPowerDbm;
        jammer.mcsThreshold = static_cast<uint8_t>(mcsThreshold);
        jammer.victimRnti = 1;
        jammer.victimCellId = 1;
        jammer.startTime = Seconds(appStart);
        jammer.stopTime = Seconds(simTime);

        std::ostringstream path;
        path << "/NodeList/" << ueNodes.Get(0)->GetId()
             << "/DeviceList/*/ComponentCarrierMapUe/*/NrUePhy/SpectrumPhy/RxPacketTraceUe";
        Config::ConnectWithoutContext(path.str(),
                                      MakeCallback(&ReactiveJammer::ObserveDl, &jammer));
        jammer.Start();
    }

    Simulator::Stop(Seconds(simTime));
    Simulator::Run();

    if (reactive)
    {
        std::cout << "reactive jammer: dutyCycle=" << jammer.DutyCycle() << " onTicks="
                  << jammer.m_onTicks << " totalTicks=" << jammer.m_totalTicks
                  << " mcsThreshold=" << mcsThreshold << std::endl;
    }

    // Victim-flow metrics (DL flow whose destination is the victim UE)
    monitor->CheckForLostPackets();
    Ptr<Ipv4FlowClassifier> classifier =
        DynamicCast<Ipv4FlowClassifier>(flowmonHelper.GetClassifier());
    Ipv4Address victimAddr = ueIpIface.GetAddress(0);
    for (const auto& kv : monitor->GetFlowStats())
    {
        Ipv4FlowClassifier::FiveTuple t = classifier->FindFlow(kv.first);
        if (t.destinationAddress != victimAddr)
        {
            continue;
        }
        const auto& s = kv.second;
        double meanDelayMs = s.rxPackets ? s.delaySum.GetSeconds() / s.rxPackets * 1000.0 : 0.0;
        uint64_t late = 0;
        const Histogram& h = s.delayHistogram;
        for (uint32_t i = 0; i < h.GetNBins(); ++i)
        {
            if (h.GetBinStart(i) >= deadlineMs / 1000.0)
            {
                late += static_cast<uint64_t>(h.GetBinCount(i));
            }
        }
        double dur = s.timeLastRxPacket.GetSeconds() - s.timeFirstTxPacket.GetSeconds();
        double thrMbps = dur > 0 ? s.rxBytes * 8.0 / dur / 1e6 : 0.0;
        double missPct =
            s.txPackets ? static_cast<double>(late + s.lostPackets) * 100.0 / s.txPackets : 0.0;
        std::cout << "METRICS tx=" << s.txPackets << " rx=" << s.rxPackets
                  << " lost=" << s.lostPackets << " meanDelayMs=" << meanDelayMs
                  << " late=" << late << " deadlineMissPct=" << missPct << " thrMbps=" << thrMbps
                  << std::endl;
    }

    std::cout << "victimUE attached to gNB0 (cellId 1); interferer "
              << (jammerEnabled ? "ON" : "OFF") << std::endl;

    Simulator::Destroy();
    return 0;
}
